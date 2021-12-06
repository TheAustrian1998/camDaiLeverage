const { expect } = require("chai");
const {
    DAIAddr,
    MAIAddr,
    amDAIAddr,
    AAVE,
    camDAIAddr,
    VaultAddr,
    DAIWhaleAddr,
    MAIWhaleAddr,
    QuickswapRouterAddr
} = require("../registry.json");

describe("camDaiLeverage", function () {

    before(async function () {
        //Deploy
        this.timeout(60000000);
        
        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [DAIWhaleAddr],
        });

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [MAIWhaleAddr],
        });
        
        [this.anotherAccount] = await ethers.getSigners();
        this.account = await ethers.getSigner(DAIWhaleAddr);
        this.MAIWhaleSigner = await ethers.getSigner(MAIWhaleAddr);

        this.LeverageFactory = await ethers.getContractFactory("LeverageFactory");
        this.leverageFactory = await this.LeverageFactory.deploy();
        await this.leverageFactory.deployed();

        this.camDaiLeverage = await ethers.getContractFactory("camDaiLeverage");

        this.gERC20 = await ethers.getContractFactory("gERC20");
        await this.gERC20.attach(DAIAddr).connect(this.account).transfer(this.anotherAccount.address, ethers.utils.parseUnits("50000"));

        //Increasing debt ceiling
        await this.gERC20.attach(MAIAddr).connect(this.MAIWhaleSigner).transfer(VaultAddr, ethers.utils.parseUnits("50000"));
    });

    async function getbalances(context, camDaiLeverageAddr) {
        console.log("\tamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(amDAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tcamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(camDAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tMAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(MAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tDAI balance (owner): ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(DAIWhaleAddr)));
        console.log("\tCollateral balance: ", ethers.utils.formatUnits(await context.camDaiLeverage.attach(camDaiLeverageAddr).getVaultCollateral()));
        console.log("\tDebt balance: ", ethers.utils.formatUnits(await context.camDaiLeverage.attach(camDaiLeverageAddr).getVaultDebt()));
        console.log("\tCollateral percentage: ", ethers.utils.formatUnits(await context.camDaiLeverage.attach(camDaiLeverageAddr).getCollateralPercentage(), "wei"));
    }

    it("Should create from factory successfully, with `account`...", async function () {
        await this.leverageFactory.connect(this.account).createNew();
        this.contractAddress = await this.leverageFactory.connect(this.account).getContractAddresses(this.account.address);
    });

    it("Do rulo, with `account`...", async function () {
        this.timeout(60000000);
        let toDeposit = ethers.utils.parseUnits("1000");
        await this.gERC20.attach(DAIAddr).connect(this.account).approve(this.contractAddress[0], toDeposit);

        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.account).doRulo(toDeposit);
        // await getbalances(this, this.contractAddress[0]);
    });

    it.skip("Undo rulo, with `account`...", async function () {
        this.timeout(60000000);
        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.account).undoRulo();
        // await getbalances(this, this.contractAddress[0]);
    });

    it.skip("Should create from factory again successfully, with `account`...", async function () {
        await this.leverageFactory.connect(this.account).createNew();
        let newContractAddressArr = await this.leverageFactory.connect(this.account).getContractAddresses(this.account.address);
        expect(newContractAddressArr.length).greaterThan(this.contractAddress.length);
    });

    it.skip("Should create from factory successfully, with `anotherAccount`...", async function () {
        await this.leverageFactory.connect(this.anotherAccount).createNew();
        this.contractAddress = await this.leverageFactory.connect(this.anotherAccount).getContractAddresses(this.anotherAccount.address);
    });

    it.skip("Do rulo, with `anotherAccount`...", async function () {
        this.timeout(60000000);
        let toDeposit = ethers.utils.parseUnits("1000");
        await this.gERC20.attach(DAIAddr).connect(this.anotherAccount).approve(this.contractAddress[0], toDeposit);

        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.anotherAccount).doRulo(toDeposit);
    });

    it.skip("Undo rulo, with `anotherAccount`...", async function () {
        this.timeout(60000000);
        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.anotherAccount).undoRulo();
    });

    it.skip("Should create from factory again successfully, with `anotherAccount`...", async function () {
        await this.leverageFactory.connect(this.anotherAccount).createNew();
        let newContractAddressArr = await this.leverageFactory.connect(this.anotherAccount).getContractAddresses(this.anotherAccount.address);
        expect(newContractAddressArr.length).greaterThan(this.contractAddress.length);
    });

});