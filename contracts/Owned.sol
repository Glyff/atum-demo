// pragma solidity ^0.4.10;

/*
 * Derived and influenced by https://www.ethereum.org/token
*/
// The creator of a contract is the owner.  Ownership can be transferred.
// The only thing we let the owner do is mint more tokens.
// So the owner is administrator/controller of the token.
contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) {
            throw;
        }
        _; // solidity 0.3.6 does not require semi-colon after
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}
