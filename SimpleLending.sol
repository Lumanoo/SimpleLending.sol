// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library DataTypes {
    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 currentLiquidityRate;
        uint128 variableBorrowIndex;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        uint16 id;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint128 accruedToTreasury;
        uint128 unbacked;
        uint128 isolationModeTotalDebt;
    }
}

interface IPool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to) external returns (uint256);

    function getReserveData(
        address asset) external view returns (DataTypes.ReserveData memory);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract AaveLender {
    address public immutable AAVE_POOL_ADDRESS = 0x48914C788295b5db23aF2b5F0B3BE775C4eA9440;
    address public immutable STAKED_TOKEN_ADDRESS = 0x7984E363c38b590bB4CA35aEd5133Ef2c6619C40;

    IPool public aavePool = IPool(AAVE_POOL_ADDRESS);
    IERC20 public stakedToken = IERC20(STAKED_TOKEN_ADDRESS);

    // Function to stake DAI and lend it on the background via AAVE
    function stake(uint256 amount) public {
        // Step 1: Transfer DAI tokens from the user to this contract
        require(stakedToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Step 2: Approve AAVE pool to spend the DAI
        require(stakedToken.approve(AAVE_POOL_ADDRESS, amount), "Approve failed");

        // Step 3: Supply DAI to AAVE pool on behalf of the user
        aavePool.supply(STAKED_TOKEN_ADDRESS, amount, msg.sender, 0);
    }

    // Function to unstake the staked amount, withdraws DAI and returns it to the user
    function unstake(uint256 amount) public {
        // Retrieve the AToken address corresponding to DAI from AAVE reserve data
        DataTypes.ReserveData memory reserveData = aavePool.getReserveData(STAKED_TOKEN_ADDRESS);
        address aTokenAddress = reserveData.aTokenAddress;
        IERC20 aToken = IERC20(aTokenAddress);

        // Step 1: Transfer aDAI tokens from the user to this contract
        require(aToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Step 2: Approve AAVE pool to spend aDAI tokens
        require(aToken.approve(AAVE_POOL_ADDRESS, amount), "Approve failed");

        // Step 3: Withdraw DAI from AAVE pool on behalf of the user
        uint256 withdrawnAmount = aavePool.withdraw(STAKED_TOKEN_ADDRESS, amount, msg.sender);
        require(withdrawnAmount == amount, "Withdraw failed");
    }
}
