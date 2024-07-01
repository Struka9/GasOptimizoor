// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "./Ownable.sol";

contract Constants {
    bool public constant tradeFlag = true;
    bool public constant basicFlag = false;
    bool public constant dividendFlag = true;
}

contract GasContract is Ownable, Constants {
    // Errors
    error GasContract__NotOwnerOrAdmin(address caller);
    error GasContract__UserNotWhitelisted(address caller);
    error GasContract__TierTooHigh(uint256 tier);
    error GasContract__NoZeroAddress();
    error GasContract__InsufficientBalance();
    error GasContract__NameTooLong();
    error GasContract__InvalidID(uint256 id);
    error GasContract__InvalidAmount(uint256 amount);

    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    uint256 public immutable totalSupply; // cannot be updated
    uint256 public paymentCounter = 0;
    mapping(address => uint256) public balances;
    uint256 public constant tradePercent = 12;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    address public immutable contractOwner;

    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName; // max 8 characters
        address recipient;
        address admin; // administrators address
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    mapping(address => bool) public isOddWhitelistUser;

    // 5 slots
    struct ImportantStruct {
        uint256 amount;
        uint256 bigValue;
        address sender;
        uint16 valueA; // max 3 digits
        uint16 valueB; // max 3 digits
        bool paymentStatus;
    }

    bool wasLastOdd = true;

    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint256 tier);

    modifier onlyAdminOrOwner() {
        address senderOfTx = msg.sender;
        if (!checkForAdmin(senderOfTx) && senderOfTx != contractOwner) {
            revert GasContract__NotOwnerOrAdmin(senderOfTx);
        }
        _;
    }

    modifier checkIfWhiteListed() {
        address senderOfTx = msg.sender;
        uint256 usersTier = whitelist[senderOfTx];
        if (usersTier < 1) {
            revert GasContract__UserNotWhitelisted(senderOfTx);
        }

        if (usersTier >= 4) {
            revert GasContract__TierTooHigh(usersTier);
        }
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(address admin, uint256 ID, uint256 amount, string recipient);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;

        address _contractOwner = msg.sender;

        uint8 len = uint8(administrators.length);
        for (uint8 ii = 0; ii < len;) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == _contractOwner) {
                    balances[_contractOwner] = _totalSupply;
                }
                if (_admins[ii] == _contractOwner) {
                    emit supplyChanged(_admins[ii], _totalSupply);
                } else {
                    emit supplyChanged(_admins[ii], 0);
                }
            }

            unchecked {
                ii++;
            }
        }
    }

    function getPaymentHistory() public view returns (History[] memory paymentHistory_) {
        paymentHistory_ = paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length;) {
            if (administrators[ii] == _user) {
                admin = true;
                break;
            }
            unchecked {
                ++ii;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        balance_ = balances[_user];
    }

    function getTradingMode() public view returns (bool mode_) {
        mode_ = tradeFlag || dividendFlag;
    }

    function addHistory(address _updateAddress, bool _tradeMode) public returns (bool status_, bool tradeMode_) {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);

        return ((tradePercent >= 1), _tradeMode);
    }

    function getPayments(address _user) public view returns (Payment[] memory payments_) {
        if (_user == address(0)) {
            revert GasContract__NoZeroAddress();
        }
        payments_ = payments[_user];
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) public returns (bool status_) {
        address senderOfTx = msg.sender;
        if (balances[senderOfTx] < _amount) {
            revert GasContract__InsufficientBalance();
        }
        if (bytes(_name).length >= 9) {
            revert GasContract__NameTooLong();
        }

        balances[senderOfTx] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[senderOfTx].push(payment);
        status_ = tradePercent >= 1;
    }

    function updatePayment(address _user, uint256 _ID, uint256 _amount, PaymentType _type) public onlyAdminOrOwner {
        if (_ID == 0) {
            revert GasContract__InvalidID(_ID);
        }

        if (_amount == 0) {
            revert GasContract__InvalidAmount(_amount);
        }

        if (_user == address(0)) {
            revert GasContract__NoZeroAddress();
        }

        address senderOfTx = msg.sender;

        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(senderOfTx, _ID, _amount, payments[_user][ii].recipientName);
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public onlyAdminOrOwner {
        if (_tier >= 255) {
            revert GasContract__TierTooHigh(_tier);
        }

        whitelist[_userAddrs] = _tier;
        if (_tier > 3 && whitelist[_userAddrs] >= _tier) {
            whitelist[_userAddrs] = 3;
        } else if (_tier == 1 && whitelist[_userAddrs] >= 1) {
            whitelist[_userAddrs] = 1;
        } else if (_tier > 0 && _tier < 3 && whitelist[_userAddrs] >= _tier) {
            whitelist[_userAddrs] = 2;
        }
        bool isOdd = !wasLastOdd;
        isOddWhitelistUser[_userAddrs] = isOdd;
        wasLastOdd = isOdd;

        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) public checkIfWhiteListed {
        address senderOfTx = msg.sender;

        ImportantStruct memory newStruct;
        newStruct.amount = _amount;
        newStruct.paymentStatus = true;
        newStruct.sender = msg.sender;
        whiteListStruct[senderOfTx] = newStruct;

        if (balances[senderOfTx] < _amount) {
            revert GasContract__InsufficientBalance();
        }

        if (_amount <= 3) {
            revert GasContract__InvalidAmount(_amount);
        }

        uint256 whitelist_ = whitelist[senderOfTx];
        uint256 delta = (_amount - whitelist_);
        balances[senderOfTx] -= delta;
        balances[_recipient] += delta;

        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        ImportantStruct memory whitelistStruct_ = whiteListStruct[sender];
        return (whitelistStruct_.paymentStatus, whitelistStruct_.amount);
    }
}
