//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/IAAVE.sol";
import "./interfaces/IcamDAI.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IQuickswapV2Router02.sol";
import "./interfaces/IUniswapV2Callee.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

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

contract camDaiLeverage is Ownable, IUniswapV2Callee {

    IERC20 private DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 private amDAI = IERC20(0x27F8D03b3a2196956ED754baDc28D73be8830A6e);
    IERC20 private MAI = IERC20(0xa3Fa99A148fA48D14Ed51d610c367C61876997F1);
    IERC20 private USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IcamDAI private camDAI = IcamDAI(0xE6C23289Ba5A9F0Ef31b8EB36241D5c800889b7b);

    IAAVE private AAVE = IAAVE(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IVault private vault = IVault(0xD2FE44055b5C874feE029119f70336447c8e8827);
    IQuickswapV2Router02 private QuickswapV2Router02 = IQuickswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    IUniswapV2Factory private  QuickswapFactory = IUniswapV2Factory(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32);

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

    function _triggerFlash(IERC20 tokenA, IERC20 tokenB, uint amountA, uint amountB, uint _type) internal {
        address pair = QuickswapFactory.getPair(address(tokenA), address(tokenB));
        require(pair != address(0), "zeroAddress");
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        uint amount0Out = address(tokenA) == token0 ? amountA : amountB;
        uint amount1Out = address(tokenA) == token1 ? amountA : amountB;

        // need to pass some data to trigger uniswapV2Call
        bytes memory data = abi.encode(address(tokenA), address(tokenA), amount0Out, amount1Out, _type);

        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
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

    function _doRulo(uint feeA) internal {
        address thisContract = address(this);
        AAVE.deposit(address(DAI), DAI.balanceOf(thisContract), thisContract, 0);
        camDAI.enter(amDAI.balanceOf(thisContract));
        uint toDeposit = camDAI.balanceOf(thisContract);
        vault.depositCollateral(vaultID, toDeposit - feeA);
        uint toBorrow = (toDeposit / (vault._minimumCollateralPercentage() + 10)) * 100; //10% secure
        vault.borrowToken(vaultID, toBorrow + feeA);
        _swap(MAI, DAI);
    }

    function _undoRulo(uint feeA) internal {
        address thisContract = address(this);

        uint debt = getVaultDebt();
        if (debt != 0) {
            vault.payBackToken(vaultID, getVaultDebt());
            vault.withdrawCollateral(vaultID, getVaultCollateral());
            camDAI.leave(camDAI.balanceOf(thisContract));
            AAVE.withdraw(address(DAI), max, thisContract);
            _swap(DAI, MAI);
        }
    }

    function _closeVault() internal {
        //Close position, send DAI to owner
        address thisContract = address(this);
        _swap(MAI, DAI);
        DAI.transfer(owner(), DAI.balanceOf(thisContract));
    }

    function doRulo(uint amount) external onlyOwner {
        DAI.transferFrom(msg.sender, address(this), amount);
        uint optimalAmount = (amount * 100) / ((vault._minimumCollateralPercentage() + 10) - 100);
        require(optimalAmount <= vault.getDebtCeiling(), "!debtCeiling");
        _triggerFlash(DAI, USDC, optimalAmount, 0, 0);
    }

    function undoRulo() external onlyOwner {
        require(getVaultDebt() > 0, "there is no rulo to undo");
        _triggerFlash(MAI, USDC, getVaultDebt(), 0, 1);
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

    //Uniswap callback
    function uniswapV2Call(address _sender, uint _amount0, uint _amount1, bytes calldata _data) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = QuickswapFactory.getPair(token0, token1);
        require(msg.sender == pair, "!pair");
        require(_sender == address(this), "!sender");

        (address tokenA, address tokenB, uint amountA, uint amountB, uint _type) = abi.decode(_data, (address, address, uint, uint, uint));

        // about 0.3% (using 0.4% preventing shortage)
        uint feeA = ((amountA * 4) / 997) + 1;
        uint amountToRepayA = amountA + feeA;

        // about 0.3% (using 0.4% preventing shortage)
        uint feeB = ((amountB * 4) / 997) + 1;
        uint amountToRepayB = amountB + feeB;

        //0 -> _doRulo
        //1 -> _undoRulo
        if (_type == 0) {
            _doRulo(feeA);
        }else{
            _undoRulo(feeA);
        }

        IERC20(tokenA).transfer(pair, amountToRepayA);
        IERC20(tokenB).transfer(pair, amountToRepayB);
    }

}