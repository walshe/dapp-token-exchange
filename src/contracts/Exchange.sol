pragma solidity ^0.5.0;

import "./Token.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


//The exchange smart contract - this is not an ERC20 contract
//Exchange 
//  allows an account to deposit or withdraw Ether or our DApp token into tht exchange
//  allows an account to make an order to buy or sell Ether or Dapp token using their avaiable exchange ether/dapp balance
//  allows an account to fill orders from the current order book

contract Exchange {
    using SafeMath for uint;

    // Variables

    address public feeAccount; // the account that receives exchange fees
    uint256 public feePercent; // the fee percentage
    address constant ETHER = address(0); // store Ether in tokens mapping with blank address

    //map of user account to another map that stores ether and Dapp balances e.g  { 'an-address' : { ETHER : 123, DAPP : 777}}
    mapping(address => mapping(address => uint256)) public tokens;
    
    //list of orders - key is just a seqeunce number
    mapping(uint256 => _Order) public orders;
    
    //we have to maintain count as mapping doesnt offer any easy way of seeing its size
    uint256 public orderCount;

    //mapping og order number to whether its cancelled or not
    mapping(uint256 => bool) public orderCancelled;

    //mapping og order number to whether its filled or not
    mapping(uint256 => bool) public orderFilled;

    // Events

    // event that models a deposit amount of a token type (ether or dapp) from a user, and new balance
    event Deposit(address token, address user, uint256 amount, uint256 balance);

    // event that models a withdrawal amount of a token type (ether or dapp) from a user, and new balance
    event Withdraw(address token, address user, uint256 amount, uint256 balance);

    // event that models an Order that was made orderId, from user acc, token type they want, its amount, token tyoe they are giving and amount and time
    event Order(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );

    // event that models an cancel Order that was made orderId, from user acc, token type they want, its amount, token tyoe they are giving and amount and time
    event Cancel(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );

    // event that models a filled order ( an actual trade ), user is user that made the order, userFill is ther user that filled the order
    event Trade(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        address userFill,
        uint256 timestamp
    );

    // Structs
    struct _Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }

    //fee account and fee percentage passed in from the migrate scripts
    constructor (address _feeAccount, uint256 _feePercent) public {
        feeAccount = _feeAccount;
        feePercent = _feePercent;
    }

    // Fallback: reverts if Ether is sent to this smart contract by mistake
    function() external {
        revert();
    }


    function depositEther() payable public {
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].add(msg.value);
        emit Deposit(ETHER, msg.sender, msg.value, tokens[ETHER][msg.sender]);
    }

    function withdrawEther(uint _amount) public {
        require(tokens[ETHER][msg.sender] >= _amount);
        tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].sub(_amount);
        msg.sender.transfer(_amount);
        emit Withdraw(ETHER, msg.sender, _amount, tokens[ETHER][msg.sender]);
    }

    function depositToken(address _token, uint _amount) public {
        require(_token != ETHER);
        require(Token(_token).transferFrom(msg.sender, address(this), _amount));
        tokens[_token][msg.sender] = tokens[_token][msg.sender].add(_amount);
        emit Deposit(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }

    function withdrawToken(address _token, uint256 _amount) public {
        require(_token != ETHER);
        require(tokens[_token][msg.sender] >= _amount);
        tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
        require(Token(_token).transfer(msg.sender, _amount));
        emit Withdraw(_token, msg.sender, _amount, tokens[_token][msg.sender]);
    }

    //get balance of ether or dapp token for any user
    function balanceOf(address _token, address _user) public view returns (uint256) {
        return tokens[_token][_user];
    }

    //make an order for what tokenb type you want, its amount and what token type and amount you are giving in exchange for it
    function makeOrder(address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) public {
        orderCount = orderCount.add(1); // increment count and use count as key for map to store the order in the next line
        orders[orderCount] = _Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
        //broadcast the event i.e an Order was made by this user for x, y, z
        emit Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
    }

    //allows user to cancel an open order
    function cancelOrder(uint256 _id) public {
        //get the order and put in storage (it is persistent between function calls and quite expensive to use.)
        _Order storage _order = orders[_id];
        //validate that it user is the person doing the cancelling
        require(address(_order.user) == msg.sender);
        //may sure id is correct
        require(_order.id == _id); // The order must exist
        //record it as cacelled
        orderCancelled[_id] = true;
        //broadcast that this order was cancelled
        emit Cancel(_order.id, msg.sender, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive, now);
    }

    //fill an order
    function fillOrder(uint256 _id) public {
        require(_id > 0 && _id <= orderCount);
        require(!orderFilled[_id]);
        //cehck it hasnt been cancelled
        require(!orderCancelled[_id]);

        //get the order and put in storage (it is persistent between function calls and quite expensive to use.)
        _Order storage _order = orders[_id];

        //fill the order
        _trade(_order.id, _order.user, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive);

        //record as filled
        orderFilled[_order.id] = true;
    }

    //helper
    function _trade(uint256 _orderId, address _user, address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) internal {
        // Fee paid by the user that fills the order, a.k.a. msg.sender.
        uint256 _feeAmount = _amountGive.mul(feePercent).div(100);

        tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(_amountGet.add(_feeAmount));
        tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(_amountGet);
        tokens[_tokenGet][feeAccount] = tokens[_tokenGet][feeAccount].add(_feeAmount);
        tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);
        tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(_amountGive);

        //broadcase the trade _user is user that made original order, msg.sender is user that filled it.
        emit Trade(_orderId, _user, _tokenGet, _amountGet, _tokenGive, _amountGive, msg.sender, now);
    }
}
