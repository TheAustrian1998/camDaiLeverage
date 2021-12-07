//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICamDAI {
    function approve(address spender, uint256 amount) external returns (bool);
    function enter(uint256 _amount) external;
    function leave(uint256 _share) external;
    function balanceOf(address account) external returns (uint256);
    function decimals() external view returns (uint256);
}