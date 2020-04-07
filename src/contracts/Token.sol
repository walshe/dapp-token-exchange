pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
    "Token" smart contract represents our new crypto currency on the eth network. This is an ERC20 smart contract which must implement certain methods from the spec
**/

contract Token {
    using SafeMath for uint;

    // Variables
    string public name = "DApp Token";
    string public symbol = "DAPP";
    uint256 public decimals = 18;
    uint256 public totalSupply;

    //map of addresses to balances
    mapping(address => uint256) public balanceOf;

    //mapping of addresses (account address) to another map of addresses (excahnge addresses or spender) to allowance
    //e.g. for any address this is the exchange and allowance that this excahnge address can spend for me
    mapping(address => mapping(address => uint256)) public allowance;

    // Events

    //fired when monmey os transfered from one address to another
    event Transfer(address indexed from, address indexed to, uint256 value);

    //fired when account address approves another excahnge address to spend an allowance
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() public {
        //lets say total supply is a million tokens
        totalSupply = 1000000 * (10 ** decimals); //multiply by 10 to power of 18 is 1000000000000000000 (as we express it by its smallest quantity)
        //assign total supply to deployer of the contract
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value); //throws error if not >=
        _transfer(msg.sender, _to, _value);
        return true;
    }

    //helper to transfer from any address to anyaddress
    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0));
        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value); //emit event
    }

    //approve a spender to spend a value
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0));
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); //emit approval
        return true;
    }

    //transfer from one address to another
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balanceOf[_from]); //check available balance
        require(_value <= allowance[_from][msg.sender]); //check allowance on the spender address
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }
}
