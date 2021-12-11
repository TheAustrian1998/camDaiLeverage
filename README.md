## **camDaiLeverage**

A tool for leveraging DAI yield in AAVE using QiDao Protocol, in Polygon Network.

### **WARNING:** **this is highly experimental**

**Detailed non-technical info**

Mechanism is as follow:

1. Take a flash-swap in DAI
2. Deposit DAI in AAVE
3. Deposit amDai in camDai Vault (QiDaoProtocol)
4. Deposit camDai as collateral in Vault (QiDaoProtocol)
5. Borrow MAI
6. Swap MAI for DAI
7. Pay flash-swap

This tool is a `Instadapp style` protocol, you can call `createNew()` function to create a new contract that only your account (`msg.sender`) can manage.

**Install**

- Clone repo

- ```
  npm install
  ```

- Create a `secrets.json` file, fill the blanks.

- ```
  npx hardhat test tests/test.js
  ```

**Functions**

*LeverageFactory:* 

- `createNew()`: create a new camDaiLeverage contract
- `getContractAddresses(address account)`: get all contract addresses by account

*camDaiLeverage:*

- `doRulo(uint amount)`: do the loop
- `undoRulo()`: undo the loop
- `transferTokens(address _tokenAddress)`: transfer any token to the owner, used for rescue tokens
