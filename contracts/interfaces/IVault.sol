//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IVault {
    function createVault() external returns (uint256);
    function depositCollateral(uint256 vaultID, uint256 amount) external;
    function withdrawCollateral(uint256 vaultID, uint256 amount) external;
    function borrowToken(uint256 vaultID, uint256 amount) external;
    function payBackToken(uint256 vaultID, uint256 amount) external;
    function checkCollateralPercentage(uint256 vaultID) external view returns (uint256);
    function _minimumCollateralPercentage() external view returns(uint256);
    function getDebtCeiling() external view returns (uint256);
    function vaultCollateral(uint256 vaultID) external view returns (uint256);
    function vaultDebt(uint256 vaultID) external view returns (uint256);
    function getEthPriceSource() external view returns (uint256);
}