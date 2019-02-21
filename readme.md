# Atum token demo
This repository contains the scripts necessary to deploy an Atum token, shield and unshield arbitrary amounts and execute shielded transfers on the  Glyff private testnet .

### Important
In order to function, this demo requires some initial parameters generated during a trusted setup,  also called *common reference string*, or CRS. Head over the release tab of [glyff-sprout params repository](https://github.com/Glyff/glyff-sprout-params) to find the download.  
Please note, the files are quite large (over 1 GB).

## Javascript Functions

The demo makes use of the ZSL API, a set of Javascript functions included in Glyff and available under the  `zsl.*`namespace. You can list them in the Glyff terminal by entering  `zsl.`  and pressing the TAB key.

The examples also make use of  `demo.js`  which is a file containing a collection of helpful functions, some of which are grouped under the  `demo.*`  namespace.

tracker:
-   tracker.shield(atumToken, value)
-   tracker.unshield(note_uuid)
-   tracker.sendNote(atumToken, note_uuid, amount, shieldedAddress)
-   tracker.list(atumToken, optional filter amount)
-   tracker.balance(atumToken)
-   tracker.load(filename)
-   tracker.save(filename)

demo:

-   demo.create_atumToken(tokenName, initialSupply)
-   demo.get_atumToken(address)
-   demo.watch_events: function(atumToken)

# Getting started

The Atum token demo can be run in two ways :

 1. By using our docker image
 2. By building glyff-node from source and setting up locally


## Setting up docker

One of the quickest ways to get Glyff up and running on your machine is by using Docker:

### Build image

    docker build -t glyff-node /home/user/glyff-node

### Run docker

    docker run -it glyff-node

This will start glyff in fast-sync mode with a DB memory allowance of 1GB just as the above command does. It will also create a persistent volume in your home directory for saving your blockchain as well as map the default ports.

Do not forget --rpcaddr 0.0.0.0, if you want to access RPC from other containers and/or hosts. By default, glyff binds to the local interface and RPC endpoints is not accessible from the outside.

## Building from source

### Building Glyff (command line client)

Install [Go](https://golang.org/) version 1.10

Building requirements for `glyff` are Go and C++ compilers, openssl, libgmp3-dev, libprocps4 and boost:

```shell
sudo apt-get install build-essential cmake git libgmp3-dev libprocps4-dev \
                     python-markdown libboost-all-dev libssl-dev 
```
Clone the repository to a directory of your choosing:

```shell
git clone https://github.com/glyff/glyff-node
```

Finally, build the `glyff` program using the following command

```shell
cd glyff-node
make glyff
```
You can now run `build/bin/glyff` to start your node


## Running the demo

 1.  Copy the files downloaded from the glyff-sprout-params repository  to your glyff datadir folder.  
 Please note, this step is necessary only when building from source.

    cp shielding.pk  shielding.vk unshielding.pk unshielding.vk transfer.pk transfer.vk ~/.glyff

 
 2.  run `glyff console` to start your glyff terminal
 
 3. load the demo.js script with  `loadScript('demo.js')` from within the Glyff console

	    $ glyff console
	    
	    Welcome to the Glyff JavaScript console!
	    instance: Glyff/v1.0.0-unstable-c3892be5/linux-amd64/go1.10
	    modules: admin:1.0 debug:1.0 eth:1.0 miner:1.0 net:1.0 personal:1.0 rpc:1.0 txpool:1.0 web3:1.0 zsl:1.0
    
	     > loadScript('demo.js')
	      true
	      

	     
   >If you don't have an account type `personal.newAccount()`, this will prompt for a password and create a new coinbase account, which you can use to mine for some testnet funds, if needed, by typing `miner.start()`
   
   ### Initializing tracker
   Unlock your account  `personal.unlockAccount(eth.accounts[0])` and initialize the script to create a keypair and a shielded address  :

    > demo.init()
    Tracker successfully initialized.
    {
          keypair: {
            a_pk: "0x7eb517122b2584588721056c5a94f0e11b1439818501fa749d03965150a60754",
            a_sk: "0x0cdb2b975b4faf9260391a40f37e5b4404dd79cf15aac625944b84a4aaa33946",
            publicKey_pkenc: "0x9739cafd9792a876812d7cccb00689d49fdc2949e26a51bca7220fd4f461a90e",
            viewingKey_skenc: "0x58a2e8341df78efa86d932ea722f387d19f10b80d8657273f9e99c9743491765",
            shieldedAddress: "0x7eb517122b2584588721056c5a94f0e11b1439818501fa749d03965150a607549739cafd9792a876812d7cccb00689d49fdc2949e26a51bca7220fd4f461a90e"
          },
          ...
        }
   ### Deploying Atum token and shielding/unshielding funds
  
  To deploy an Atum token :
```
atu = demo.create_atumToken('MyToken', 1000000000000)

```
Wait for the transaction to be mined, explore your token and start the event watcher :

	atu.address()
	atu.balance()
    demo.watch_events(atu)

To shield some transparent funds :

     tracker.shield(atu,  100)
     ***************************************************************
    [*] Generating proof for shielding
    [*] Generated in 2.61 secs
    "Waiting for log event..."
    > [*] Shielding added to contract.
    ***************************************************************
    note uuid : 0x93eb055615760e74500dd0bc7c965fa51b2471403fd71cd3f92c5de446665920
   
Tracker state can also be explored by typing `tracker.notes` or `tracker.spent`. 

To unshield a specific note by its unique identifier  :

    > tracker.unshield('0x93eb055615760e74500dd0bc7c965fa51b2471403fd71cd3f92c5de446665920')
    ***************************************************************
    [*] Generating proof for unshielding
    [*] Generated in 45.887 secs
    "Waiting for log event..."
    > [*] Unshielding added to contract.
    ***************************************************************

### Shielded transfer of notes
Transfers of zero-knowledge notes to another shielded address are enabled via "join-split"-style transactions and accessed via the `sendNote` method.  To test the  shielded transfer launch a separate glyff terminal with `glyff attach` , initialize  tracker to generate a shielded address and connect to your Atum token :

    > demo.init()
    Tracker successfully initialized.
    {
      keypair: {
        a_pk: "0xe5d4e66121c350441da53a49bd3e02a0fa54e3ba2acc06ad0e854b1eb49e1560",
        a_sk: "0x08f49d12b8655f1d397cf61ae1cb53bb2e6a30f91e000cd80dbb258b7534bb90",
        publicKey_pkenc: "0xb44b69ea039bcd85b1496b8af7b6c94c342324bb361a0bcbb6c0c3bdc480f849",
        viewingKey_skenc: "0x30d6d11a79d78b15360178cadd47bd2c36a6078d8aa1d50b60da91bfa0cdb256",
        shieldedAddress: "0xe5d4e66121c350441da53a49bd3e02a0fa54e3ba2acc06ad0e854b1eb49e1560b44b69ea039bcd85b1496b8af7b6c94c342324bb361a0bcbb6c0c3bdc480f849"
      },
      ...
    }
    > atu = demo.get_atumToken('0x04ba7566eea5d520d650605447b363d30598a491')
    > demo.watch_events(atu)

To send a note from the main terminal:

 
    > tracker.sendNote(atu, '0x93eb055615760e74500dd0bc7c965fa51b2471403fd71cd3f92c5de446665920', 10, '0xe5d4e66121c350441da53a49bd3e02a0fa54e3ba2acc06ad0e854b1eb49e1560b44b69ea039bcd85b1496b8af7b6c94c342324bb361a0bcbb6c0c3bdc480f849')
    ***************************************************************
    [*] Generating proof for shielded transfer
    [*] Generated in 90.921 secs
    [*] Recipient receives note of 10 ATU
    [*] Sender receives change of 90 ATU
    [*] Submit shielded transfer to contract...
    "Waiting for log event..."
    > [*] Shielded-transfer added to contract.
    ***************************************************************

Once the transaction is mined, a notification will be printed to screen on the receiving end :

    > [*] Incoming funds! amount : 10 ATU
    *************************************************************** 

## Tracker persistance
### [WIP]
