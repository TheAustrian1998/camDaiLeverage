const { expect } = require("chai");
const {
    DAIAddr,
    MAIAddr,
    amDAIAddr,
    AAVE,
    camDAIAddr,
    VaultAddr,
    whaleAddr,
    QuickswapRouterAddr
} = require("../registry.json");

describe("camDaiLeverage", function () {

    before(async function () {
        //Deploy
        this.timeout(60000);

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [whaleAddr],
        });

        this.account = await ethers.getSigner(whaleAddr);

        this.LeverageFactory = await ethers.getContractFactory("LeverageFactory");
        this.leverageFactory = await this.LeverageFactory.deploy();
        await this.leverageFactory.deployed();

        this.camDaiLeverage = await ethers.getContractFactory("camDaiLeverage");

        this.gERC20 = await ethers.getContractFactory("gERC20");
    });

    async function getbalances(context, camDaiLeverageAddr) {
        console.log("\tamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(amDAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tcamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(camDAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tMAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(MAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(camDaiLeverageAddr)));
        console.log("\tDAI balance (owner): ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(whaleAddr)));
        console.log("\tCollateral balance: ", ethers.utils.formatUnits(await context.camDaiLeverage.attach(camDaiLeverageAddr).getVaultCollateral()));
        console.log("\tDebt balance: ", ethers.utils.formatUnits(await context.camDaiLeverage.attach(camDaiLeverageAddr).getVaultDebt()));
    }

    it("Should create from factory successfully...", async function () {
        await this.leverageFactory.connect(this.account).createNew();
        this.contractAddress = await this.leverageFactory.connect(this.account).getContractAddresses(this.account.address);
    });

    it("Do rulo...", async function () {
        this.timeout(60000);
        let toDeposit = ethers.utils.parseUnits("1000");
        await this.gERC20.attach(DAIAddr).connect(this.account).approve(this.contractAddress[0], toDeposit);

        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.account).doRulo(toDeposit, 10);
        await getbalances(this, this.contractAddress[0]);
    });

    it("Undo rulo...", async function () {
        this.timeout(60000);
        await this.camDaiLeverage.attach(this.contractAddress[0]).connect(this.account).undoRulo();
        await getbalances(this, this.contractAddress[0]);
    });

    it("Should create from factory again successfully...", async function () {
        await this.leverageFactory.connect(this.account).createNew();
        let newContractAddressArr = await this.leverageFactory.connect(this.account).getContractAddresses(this.account.address);
        expect(newContractAddressArr.length).greaterThan(this.contractAddress.length);
    });

});