//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/IAAVE.sol";
import "./interfaces/IcamDAI.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IQuickswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract camDaiLeverage is Ownable {

    IERC20 public DAI;
    IERC20 public amDAI;
    IERC20 public MAI;
    IAAVE public AAVE;
    IcamDAI public camDAI;
    IVault public vault;
    IQuickswapV2Router02 public QuickswapV2Router02;
    uint public vaultID;
    uint constant private max = type(uint256).max;

    constructor(address _DAI,address _amDAI, address _MAI, address _IAAVE, address _camDAI, address _vault, address _IQuickswapV2Router02) {
        DAI = IERC20(_DAI);
        amDAI = IERC20(_amDAI);
        MAI = IERC20(_MAI);

        AAVE = IAAVE(_IAAVE);
        camDAI = IcamDAI(_camDAI);
        vault = IVault(_vault);
        QuickswapV2Router02 = IQuickswapV2Router02(_IQuickswapV2Router02);
        
        vaultID = vault.createVault();
        DAI.approve(_IAAVE, max);
        amDAI.approve(_camDAI, max);
        camDAI.approve(_vault, max);
        MAI.approve(_vault, max);
        MAI.approve(_IQuickswapV2Router02, max);
        DAI.approve(_IQuickswapV2Router02, max);
    }

    function _swap(IERC20 _in, IERC20 _out) internal {
        //in -> out
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
        //If it isn't last execution, swap to deposit again
        if (!isLastExec){
            uint toBorrow = (toDeposit / (vault._minimumCollateralPercentage() + 10)) * 100;
            vault.borrowToken(vaultID, toBorrow);
            _swap(MAI, DAI);
        }
    }

    function doRulo(uint amount, uint loopTimes) external onlyOwner {
        require(loopTimes <= 10, "dont be greedy");
        DAI.transferFrom(msg.sender, address(this), amount);
        
        for (uint256 i = 0; i < loopTimes - 1; i++) {
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

            uint toWithdraw = debt * (diff - 10) / 100;
            // console.log(diff, collPerc, toWithdraw);
            vault.withdrawCollateral(vaultID, toWithdraw);
            camDAI.leave(camDAI.balanceOf(thisContract));
            AAVE.withdraw(address(DAI), max, thisContract);
            _swap(DAI, MAI);
            uint toPay = MAI.balanceOf(thisContract) >= debt ? debt : MAI.balanceOf(thisContract);
            if (toPay != 0) {
                vault.payBackToken(vaultID, toPay);
            }
        }
    }

    function _closeVault() internal {
        address thisContract = address(this);
        vault.withdrawCollateral(vaultID, getVaultCollateral());
        camDAI.leave(camDAI.balanceOf(thisContract));
        AAVE.withdraw(address(DAI), max, thisContract);
        _swap(MAI, DAI);
        DAI.transfer(owner(), DAI.balanceOf(thisContract));
    }

    function undoRulo() external onlyOwner {
        //Deshacer rulo en un for mas de 10 veces (12 por ejemplo) y poner if que salte el loop si es que no hay deuda por pagar
        for (uint256 i = 0; i < 12; i++) {  
            _undoRulo();
        }
        _closeVault();        
    }

    function getVaultCollateral() public view returns (uint256) {
        return vault.vaultCollateral(vaultID);
    }

    function getVaultDebt() public view returns (uint256) {
        return vault.vaultDebt(vaultID);
    }

}