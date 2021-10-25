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
        this.timeout( 60000 );

        await hre.network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [whaleAddr],
        });

        this.account = await ethers.getSigner(whaleAddr);

        this.camDaiLeverage = await ethers.getContractFactory("camDaiLeverage");
        this._camDaiLeverage = await this.camDaiLeverage.connect(this.account).deploy(DAIAddr, amDAIAddr, MAIAddr, AAVE, camDAIAddr, VaultAddr, QuickswapRouterAddr);
        await this._camDaiLeverage.deployed();

        this.gERC20 = await ethers.getContractFactory("gERC20");
    });

    async function getbalances(context){
        console.log("\tamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(amDAIAddr).balanceOf(context._camDaiLeverage.address)));
        console.log("\tcamDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(camDAIAddr).balanceOf(context._camDaiLeverage.address)));
        console.log("\tMAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(MAIAddr).balanceOf(context._camDaiLeverage.address)));
        console.log("\tDAI balance: ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(context._camDaiLeverage.address)));
        console.log("\tDAI balance (owner): ", ethers.utils.formatUnits(await context.gERC20.attach(DAIAddr).balanceOf(whaleAddr)));
        console.log("\tCollateral balance: ", ethers.utils.formatUnits(await context._camDaiLeverage.getVaultCollateral()));
        console.log("\tDebt balance: ", ethers.utils.formatUnits(await context._camDaiLeverage.getVaultDebt()));
    }

    it("Do rulo...", async function () {
        this.timeout( 60000 );
        let toDeposit = ethers.utils.parseUnits("1000");
        await this.gERC20.attach(DAIAddr).connect(this.account).approve(this._camDaiLeverage.address, toDeposit);

        await this._camDaiLeverage.connect(this.account).doRulo(toDeposit, 10);
        await getbalances(this);
    });

    it("Undo rulo...", async function(){
        this.timeout( 60000 );
        await this._camDaiLeverage.connect(this.account).undoRulo();
        await getbalances(this);
    });

});