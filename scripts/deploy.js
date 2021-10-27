const hre = require("hardhat");

async function main() {
    await hre.run("clean");
    await hre.run("compile");

    this.LeverageFactory = await ethers.getContractFactory("LeverageFactory");
    this.leverageFactory = await this.LeverageFactory.deploy();
    await this.leverageFactory.deployed();

    console.log("Deployed at:", this.leverageFactory.address);

    //Verify
    await hre.run("verify:verify", {
        address: this.leverageFactory.address
    });
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });