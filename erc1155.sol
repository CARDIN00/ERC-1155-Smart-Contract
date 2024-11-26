// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//semi fungible (that start as fungible but later become NFT)
// ERC1155 Receiver Interface
interface IERC1155Receiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

contract BasiERC1155{
    address public Owner;

    //MAPPINGS

    //token Id to account balance
    mapping(uint => mapping (address=> uint))private Balance;//{id => user =>balance}

    mapping(address => mapping(address => bool)) private Approval;

    mapping(uint => string) private _uris; // Metadata URIs

    //EVENTS
    event mint(address indexed from,address indexed to, uint id, uint amount);
    event transfer(address indexed from,address indexed to, uint id, uint amount, uint time);
    event batchtransfer(address indexed from,address indexed to, uint[] ids, uint[] amounts, uint time);


    // INTERFACE IDs (for ERC-165)
    bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 private constant _INTERFACE_ID_ERC1155_RECEIVER = 0x4e2312e0;
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    //MODIFIER
    modifier onlyOwner{
        require(msg.sender == Owner);
        _;
    }

    //FUNCTIONS

    // URI FUNCTIONS
    function setURI(uint id, string memory uri) public onlyOwner {
        _uris[id] = uri;
    }

    function getUri(uint id) public view returns (string memory) {
        return _uris[id];
    }

    // ERC-165 SUPPORT
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == _INTERFACE_ID_ERC1155 ||
            interfaceId == _INTERFACE_ID_ERC1155_RECEIVER ||
            interfaceId == _INTERFACE_ID_ERC165;
    }
    
    //function to get the balance
    function balanceOf(address account , uint id)public  view returns(uint){
        require(account != address(0), "Enter a valid address");
        return Balance[id][account];
    }

    //function to check if the reciever is a contract
    function isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }



    //Mint function
    function Mint( address _to,uint id, uint _amount) public returns(bool){
        require(_to != address(0),"Can not mint to invalid address");
        Balance[id][_to] += _amount;

        emit mint(msg.sender, _to, id, _amount);
        return true;
    }

    //transfer token bw accounts
    function Transfer(
        address from ,
        address to ,
        uint id,
        uint amount,
        bytes memory data)
        public returns (bool)
        {
        require(to != address(0));
        require(from != address(0));
        require(amount != 0,"amount being sent can not be zero");
        require(from ==msg.sender || isApprovedForAll(from, msg.sender));

        Balance[id][from] -= amount;
        Balance[id][to] += amount;

        uint time = block.timestamp;
        
        emit transfer(from, to, id, amount, time);
         if (isContract(to)) {
            require(
                IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, amount, data) == bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")),
                "ERC1155: transfer to non ERC1155Receiver implementer"
            );
        }
        return true;
    }

    //Batch transfer(send the diffrent amount of different token id's)
    function BatchTransfer(
            address from ,
            address to,
            uint[] memory _amounts,
            uint[] memory _ids,
            bytes memory data
            )public returns(bool)
           {
        require(from != address(0));
        require(to != address(0));
        require(_ids.length == _amounts.length," the lengths of the array mismatch" );
        require(from ==msg.sender || isApprovedForAll(from, msg.sender));

        for (uint i=0; i<_ids.length; i++) {
            uint id= _ids[i];
            uint amount = _amounts[i];
            
            require(Balance[id][from] >= amount);
            Balance[id][from] -= amount;
            Balance[id][to] += amount;
            
        }
        uint time = block.timestamp;
        emit batchtransfer(from, to, _ids, _amounts, time);

         // Call the receiving contract's hook if it implements it
        // Call the receiving contract's hook if it implements it
        if (isContract(to)) {
            require(
                IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, _ids, _amounts, data) == bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)")),
                "ERC1155: transfer to non ERC1155Receiver implementer"
            );
        }
        return  true; 

    }

    //sets the approval for all
    function setApprovalForAll(
        address operator,
        bool approved
        )public 
        {
        require(operator != msg.sender);
        Approval[msg.sender][operator] = approved;

    }

    //check if is approved for all
    function isApprovedForAll(address from ,address operator) public view returns (bool){
        return Approval[from][operator];
    }

    //BURN functions
    // single burn 
    function BunrSingle(
        address from,
        uint id,
        uint amount
    )public  returns (bool){
        require(from != address(0));
        require(from == msg.sender);
        require(Balance[id][from] >= amount);

        Balance[id][from] -= amount;
        emit transfer(from, address(0), id, amount, block.timestamp);
        return true;
    }

    // batch burn
    function burnBatch(
        address from,
        uint[] memory ids,
        uint[] memory amounts
    )public returns(bool){
        require(from != address(0));
        require(from == msg.sender || isApprovedForAll(from, msg.sender));
        require(ids.length == amounts.length);

        for(uint i =0; i< ids.length; i++){
            uint id = ids[i];
            uint amount = amounts[i];

            require(Balance[id][from] >= amount);
            Balance[id][from] -= amount;
        }

        emit batchtransfer(from,address(0), ids, amounts, block.timestamp);
        return  true;
    }
}
