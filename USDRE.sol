// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract DollarPeggedToken {
    string public constant name = "USDRE";
    string public constant symbol = "USDRE";
    uint8 public constant decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeeTaken(uint256 fee, uint256 newBalance);
    event PurchasedUSDRE(address buyer, uint256 avaxSpent, uint256 usdreMinted);
    event Received(address sender, uint256 amount);

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    uint256 public totalSupply;
    address public owner;
    bool public paused = false;
    uint256 public feeBalance;
    uint256 public transferFeeRate = 5;  // Fee rate as a percentage of the transfer amount


    // Fallback function used to receive AVAX
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        _mint(owner, initialSupply);
    }

    // Function to retrieve the contract's AVAX balance
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to withdraw all AVAX from the contract
    function withdrawAll() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");
        balanceOf[account] += amount;
        totalSupply += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn from the zero address");
        require(balanceOf[account] >= amount, "Burning amount exceeds balance");
        balanceOf[account] -= amount;
        totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    function transfer(address to, uint256 amount) public whenNotPaused returns (bool) {
        require(to != address(0), "Transfer to the zero address");
        require(balanceOf[msg.sender] >= amount, "Transfer amount exceeds balance");

        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amountAfterFee;
        feeBalance += fee;

        emit Transfer(msg.sender, to, amountAfterFee);
        emit FeeTaken(fee, feeBalance);

        return true;
    }

    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        require(spender != address(0), "Approve to the zero address");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public whenNotPaused returns (bool) {
        require(from != address(0) && to != address(0), "Transfer from/to the zero address");
        require(balanceOf[from] >= amount, "Transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= amount, "Transfer amount exceeds allowance");

        uint256 fee = calculateFee(amount);
        uint256 amountAfterFee = amount - fee;

        balanceOf[from] -= amount;
        balanceOf[to] += amountAfterFee;
        allowance[from][msg.sender] -= amount;
        feeBalance += fee;

        emit Transfer(from, to, amountAfterFee);
        emit FeeTaken(fee, feeBalance);

        return true;
    }

    function calculateFee(uint256 amount) private view returns (uint256) {
        return amount * transferFeeRate / 100;
    }

    function buyUSDREWithAVAX() public payable whenNotPaused {
        require(msg.value > 0, "Need to send AVAX");
        uint256 usdreAmount = msg.value * 40;  // 1 AVAX = 40 USDRE
        _mint(msg.sender, usdreAmount);
        emit PurchasedUSDRE(msg.sender, msg.value, usdreAmount);
    }

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
