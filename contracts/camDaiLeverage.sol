//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/IAAVE.sol";
import "./interfaces/IcamDAI.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IQuickswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LeverageFactory {

    mapping(address => address[]) public index;

    function createNew() external returns (address) {
        camDaiLeverage _camDaiLeverage = new camDaiLeverage(msg.sender);
        address contractAddress = address(_camDaiLeverage);
        index[msg.sender].push(contractAddress);
        return contractAddress;
    }

    function getContractAddresses(address account) external view returns (address[] memory) {
        return index[account];
    }

}

contract camDaiLeverage is Ownable {

    IERC20 public DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 public amDAI = IERC20(0x27F8D03b3a2196956ED754baDc28D73be8830A6e);
    IERC20 public MAI = IERC20(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1);
    IAAVE public AAVE = IAAVE(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IcamDAI public camDAI = IcamDAI(0xE6C23289Ba5A9F0Ef31b8EB36241D5c800889b7b);
    IVault public vault = IVault(0xD2FE44055b5C874feE029119f70336447c8e8827);
    IQuickswapV2Router02 public QuickswapV2Router02 = IQuickswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    uint public vaultID;
    uint constant private max = type(uint256).max;

    constructor (address _newOwner) {
        //Create vault
        vaultID = vault.createVault();
        //Approves
        DAI.approve(address(AAVE), max);
        amDAI.approve(address(camDAI), max);
        camDAI.approve(address(vault), max);
        MAI.approve(address(vault), max);
        MAI.approve(address(QuickswapV2Router02), max);
        DAI.approve(address(QuickswapV2Router02), max);
        //Transfer ownership
        transferOwnership(_newOwner);
    }

    function _swap(IERC20 _in, IERC20 _out) internal {
        //swap in -> out
        uint256 _inBalance = _in.balanceOf(address(this));

        if (_inBalance != 0) {
            address[] memory path = new address[](2);
            path[0] = address(_in);
            path[1] = address(_out);

            uint256[] memory amountsOut = QuickswapV2Router02.getAmountsOut(
                _inBalance,
                path
            );

            uint256 minAmount = amountsOut[1] - ((amountsOut[1] * 1) / 100); // 1% slippage
            address receiver = address(this);

            QuickswapV2Router02.swapExactTokensForTokens(
                _inBalance,
                minAmount,
                path,
                receiver,
                block.timestamp
            );
        }
    }

    function _doRulo(bool isLastExec) internal {
        address thisContract = address(this);
        AAVE.deposit(address(DAI), DAI.balanceOf(thisContract), thisContract, 0);
        camDAI.enter(amDAI.balanceOf(thisContract));
        uint toDeposit = camDAI.balanceOf(thisContract);
        vault.depositCollateral(vaultID, toDeposit);
        //If isn't last execution, swap for DAI to deposit again
        if (!isLastExec){
            uint toBorrow = (toDeposit / (vault._minimumCollateralPercentage() + 10)) * 100; //10% secure
            vault.borrowToken(vaultID, toBorrow);
            _swap(MAI, DAI);
        }
    }

    function doRulo(uint amount) external onlyOwner {
        DAI.transferFrom(msg.sender, address(this), amount);
        
        for (uint256 i = 0; i < 10 - 1; i++) {
            _doRulo(false);
        }
        _doRulo(true);
    }

    function _undoRulo() internal {
        address thisContract = address(this);

        uint debt = getVaultDebt();
        if (debt != 0) {
            uint collPerc = vault.checkCollateralPercentage(vaultID);
            uint minCollPerc = vault._minimumCollateralPercentage();
            uint diff = collPerc - minCollPerc;

            uint toWithdraw = debt * (diff - 10) / 100; //Difference is always more than 10% (see `_doRulo()`)
            vault.withdrawCollateral(vaultID, toWithdraw);
            camDAI.leave(camDAI.balanceOf(thisContract));
            AAVE.withdraw(address(DAI), max, thisContract);
            _swap(DAI, MAI);
            uint toPay = MAI.balanceOf(thisContract) >= debt ? debt : MAI.balanceOf(thisContract); //Choose min value
            if (toPay != 0) {
                vault.payBackToken(vaultID, toPay);
            }
        }
    }

    function _closeVault() internal {
        //Close position, send DAI to owner
        address thisContract = address(this);
        vault.withdrawCollateral(vaultID, getVaultCollateral());
        camDAI.leave(camDAI.balanceOf(thisContract));
        AAVE.withdraw(address(DAI), max, thisContract);
        _swap(MAI, DAI);
        DAI.transfer(owner(), DAI.balanceOf(thisContract));
    }

    function undoRulo() external onlyOwner {
        require(getVaultDebt() > 0, "there is no rulo to undo");
        //Loop more than necessary
        for (uint256 i = 0; i < 12; i++) {
            _undoRulo();
        }
        _closeVault();
    }

    function transferTokens(address _tokenAddress) external onlyOwner {
        //Used for "rescue" tokens
        IERC20(_tokenAddress).transfer(owner(), IERC20(_tokenAddress).balanceOf(address(this)));
    }

    function getVaultCollateral() public view returns (uint256) {
        return vault.vaultCollateral(vaultID);
    }

    function getVaultDebt() public view returns (uint256) {
        return vault.vaultDebt(vaultID);
    }

    function getCollateralPercentage() public view returns (uint256) {
        return vault.checkCollateralPercentage(vaultID);
    }

}