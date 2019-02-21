// pragma solidity ^0.4.10;

// Copyright 2017 Zerocoin Electric Coin Company LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


/**
 Design note: We inherit from ZSLMerkleTree rather than proxying messages such as
 depth() and size(), to avoid compile error "inaccessible dynamic type error" due to
 language limitations (or bugs?) when marshalling data from one contract to another.
 */
contract Atum is owned, SafeMath, ZSLMerkleTree {
    // Depth of the merkle tree decides how many notes this contract can store 2^depth.
    uint constant public ATUM_TREE_DEPTH = 29;

    // Name of token
    string public name;

    // Monetary supply of token
    uint256 public totalSupply;
    uint8 public constant decimals = 12;
    
    // Map of all public (transparent) balances
    mapping (address => uint256) public balanceOf;
    mapping (address => uint256) public replayNonce;

    // Counters
    uint256 public shieldingCount;
    uint256 public unshieldingCount;
    uint256 public shieldedTransferCount;

    // Address for ZSL contract
    address private address_zsl;

    // ZSL contract
    ZSLPrecompile private zsl;

    // Map of send and spending nullifiers (when creating and consuming shielded notes)
    mapping (bytes32 => uint) private mapNullifiers;

    // Public events to notify listeners
    event LogTransfer(address indexed from, address indexed to, uint256 value);
    event LogMint(address indexed to, uint256 amount);
    event LogShielding(address indexed from, uint256 value, bytes32 uuid);
    event LogUnshielding(address indexed from, uint256 value, bytes32 uuid);
    event LogShieldedTransfer(address indexed from, bytes32 uuid_1, bytes32 uuid_2, string blob);

    /* @notice Constructor. Initial supply of tokens are deposited in the account of the creator of the contract. Super constructor for ZSLMerkleTree is invoked here too.
     * @param left uint256
     * @param name string
     */
    function Atum(uint256 ownerBalance, string tokenName) ZSLMerkleTree(ATUM_TREE_DEPTH) {
        balanceOf[msg.sender] = ownerBalance;
        name = tokenName;
        totalSupply = 1000000 * 10**uint(decimals);
        // Create contract for precompiles and commitment tree
        address_zsl = new ZSLPrecompile();
        zsl = ZSLPrecompile(address_zsl);
    }

    /**
     * @return capacity Token balance for message sender.
     */
    function balance() public constant returns (uint256) {
        return this.balanceOf(msg.sender);
    }

    /**
     * @return capacity Maxmimum number of shielded transactions this contract can process
     */
    function shieldedTxCapacity() public constant returns (uint) {
        return capacity() / 2;
    }

    /**
     * @return available The number of shielded transactions that can be still be processed
     */
    function shieldedTxAvailable() public constant returns (uint) {
        return shieldedTxCapacity() - shieldedTransferCount;
    }


    // Send tokens from public pool of funds (not private shielded funds).
    function transfer(address recipient, uint256 value) {
        require(balanceOf[msg.sender] >= value);           // check if the sender has enough
        balanceOf[msg.sender] = safeSubtract(balanceOf[msg.sender], value);     // check for underflow
        balanceOf[recipient] = safeAdd(balanceOf[recipient], value);    // check for overflow
        LogTransfer(msg.sender, recipient, value);
    }

    /**
     * Add shielding of non-private funds
     * atum.shield(proof, send_nf, cm, value, {from:eth.accounts[0],gas:5470000});
     */
    function shield(bytes proof, bytes32 send_nf, bytes32 cm, uint64 value) public {
        require(balanceOf[msg.sender] >= value);    // check if the sender has enough funds to shield
        require(mapNullifiers[send_nf] == 0);             // check if nullifier has been used before
        require(!commitmentExists(cm));
        assert(zsl.verifyShielding(proof, send_nf, cm, value));     // verfy proof
        addCommitment(cm);       // will assert if cm has already been added or the tree is full
        mapNullifiers[send_nf] = 1;
        balanceOf[msg.sender] = safeSubtract(balanceOf[msg.sender], value);     // check for underflow
        LogShielding(msg.sender, value, sha3(cm));
        shieldingCount++;
    }

    /**
     * Add unshielding of private funds
     * atum.unshield(proof, spend_nf, cm, rt, value, {from:eth.accounts[0],gas:5470000});
     */
    function unshield(bytes proof, bytes32 spend_nf, bytes32 cm, bytes32 rt, uint64 value) public {
        require(mapNullifiers[spend_nf] == 0);             // check if nullifier has been used before
        require(commitmentExists(cm));
        assert(zsl.verifyUnshielding(proof, spend_nf, rt, value));     // verify proof
        mapNullifiers[spend_nf] = 1;
        balanceOf[msg.sender] = safeAdd(balanceOf[msg.sender], value);     // check for overflow
        LogUnshielding(msg.sender, value, sha3(cm));
        unshieldingCount++;
    }

    /**
     * Add shielded transfer of privatefunds
     * atum.shieldedTransfer(proof, anchor, in_spend_nf_1, in_spend_nf_2, out_send_nf_1, out_send_nf_2, out_cm_1, out_cm_2, blob, {from:eth.accounts[0], gas:5470000});
     */
    function shieldedTransfer(
        bytes proof, bytes32 anchor,
        bytes32 spend_nf_1, bytes32 spend_nf_2,
        bytes32 send_nf_1, bytes32 send_nf_2,
        bytes32 cm_1, bytes32 cm_2, string blob
    ) public {
        require(mapNullifiers[send_nf_1] == 0);
        require(mapNullifiers[send_nf_2] == 0);
        require(mapNullifiers[spend_nf_1] == 0);
        require(mapNullifiers[spend_nf_2] == 0);
        require(!commitmentExists(cm_1));
        require(!commitmentExists(cm_2));
        assert(zsl.verifyShieldedTransfer(
            proof, anchor,
            spend_nf_1, spend_nf_2,
            send_nf_1, send_nf_2,
            cm_1, cm_2 ));
        addCommitment(cm_1);
        addCommitment(cm_2);
        mapNullifiers[send_nf_1] = 1;
        mapNullifiers[send_nf_2] = 1;
        LogShieldedTransfer(msg.sender, sha3(cm_1), sha3(cm_2), blob);
        shieldedTransferCount++;
    }

    // Fallback function for unknown function signature to prevent accidental sending of funds
    function () {
        revert();
    }

    /*
      Utility functions when compiling with solidity 0.3.6
    */
    function assert(bool assertion) internal {
      if (!assertion) {
        throw;
      }
    }

    function require(bool requirement) internal {
      if (!requirement) {
        throw;
      }
    }

    function revert() internal {
      throw;
    }
}