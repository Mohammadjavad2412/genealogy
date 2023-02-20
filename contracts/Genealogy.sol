// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Genealogy {
    struct Partner {
        uint256 position_id;
        uint256 upline_position_id;
        address wallet_addres;
        string ebr_code;
        string direction; // left or right of the upline
        uint256 balance;
        uint256 created_at;
        uint256 last_update;
        bool isValue;
    }

    mapping(uint256 => Partner) public partnersByPositionId;
    mapping(address => Partner) public partnersByWalletAddress;
    mapping(string => Partner) public partnersByEbrCode;
    mapping(uint256 => Partner) public balancesByPositionId;
    uint256 left_child;
    uint256 sub_child_numbers;
    uint256 sub_child;
    uint256 position_id_from_ebr_code;
    uint256[] childs;
    uint256 partnerCount;
    uint256[] position_ids;
    uint256 _upline_position_id;
    uint256 _new_position_id;

    constructor(string memory _admin_ebr_code) payable {
        partnerCount = 0;
        // string memory admin_ebr_code = Strings.toString(_admin_ebr_code);
        addPartner(_admin_ebr_code, "none", "none", 100);
    }

    function isValidEbrCode(string memory _ebr_code)
        public
        view
        returns (bool)
    {
        if (partnersByEbrCode[_ebr_code].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function isValidPositionId(uint256 _position_id)
        public
        view
        returns (bool)
    {
        if (partnersByPositionId[_position_id].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function isValidDirection(string memory _direction)
        public
        view
        returns (bool)
    {
        if (
            keccak256(abi.encodePacked(_direction)) ==
            keccak256(abi.encodePacked("l")) ||
            keccak256(abi.encodePacked(_direction)) ==
            keccak256(abi.encodePacked("r"))
        ) {
            return true;
        } else {
            return false;
        }
    }

    function generatePositionId(
        uint256 _upline_postion_id,
        string memory _direction
    ) public returns (uint256) {
        require(
            isValidDirection(_direction) == true,
            "invalid direction passed. direction should be r or l (r for right and l for left)"
        );
        require(
            isValidPositionId(_upline_postion_id) == true,
            "invalid upline position_id"
        );
        if (
            keccak256(abi.encodePacked(_direction)) ==
            keccak256(abi.encodePacked("r"))
        ) {
            _new_position_id = _upline_postion_id * 2 + 2;
            return (_new_position_id);
        } else {
            _new_position_id = _upline_postion_id * 2 + 1;
            return (_new_position_id);
        }
    }

    function getPositionIdFromEbrCode(string memory _ebr_code)
        public
        returns (uint256)
    {
        if (isValidEbrCode(_ebr_code) == true) {
            Partner storage partner = partnersByEbrCode[_ebr_code];
            position_id_from_ebr_code = partner.position_id;
            return position_id_from_ebr_code;
        }
    }

    function addPartner(
        string memory _ebr_code,
        string memory _direction,
        string memory _upline_ebr_code,
        uint256 _balance
    ) public returns (uint256[] memory) {
        if (
            keccak256(abi.encodePacked(_upline_ebr_code)) ==
            keccak256(abi.encodePacked("none"))
        ) {
            _upline_position_id = 0;
            _new_position_id = 0;
        } else {
            uint256 _upline_position_id = getPositionIdFromEbrCode(
                _upline_ebr_code
            );
            uint256 _new_position_id = generatePositionId(
                _upline_position_id,
                _direction
            );
        }

        Partner memory partner = Partner(
            _new_position_id,
            _upline_position_id,
            msg.sender,
            _ebr_code,
            _direction,
            _balance,
            block.timestamp,
            block.timestamp,
            true
        );
        partnersByEbrCode[_ebr_code] = partner;
        position_ids.push(_new_position_id); // storing all position ids
        partnersByPositionId[_new_position_id] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        partnerCount++;
    }

    function getPositionIdList() public view returns (uint256[] memory) {
        return position_ids;
    }

    function countPositionIds() public view returns (uint256) {
        return position_ids.length;
    }

    function getPartner(uint256 _position_id)
        public
        view
        returns (Partner memory)
    {
        return partnersByPositionId[_position_id];
    }

    function getPartners()
        public
        view
        returns (
            uint256[] memory,
            address[] memory,
            string[] memory,
            string[] memory,
            uint256[] memory
        )
    {
        uint256[] memory id = new uint256[](partnerCount);
        address[] memory wallet_address = new address[](partnerCount);
        string[] memory ebr_code = new string[](partnerCount);
        string[] memory direction = new string[](partnerCount);
        uint256[] memory balance = new uint256[](partnerCount);
        for (uint256 i = 0; i < partnerCount; i++) {
            Partner storage partner = partnersByPositionId[i];
            id[i] = partner.position_id;
            wallet_address[i] = partner.wallet_addres;
            ebr_code[i] = partner.ebr_code;
            direction[i] = partner.direction;
            balance[i] = partner.balance;
        }
        return (id, wallet_address, ebr_code, direction, balance);
    }

    function calc_next_child(uint256 _number) public returns (uint256) {
        left_child = _number * 2 + 1;
        return left_child;
    }

    function calc_childs(uint256 _number, uint256 _level)
        public
        returns (uint256[] memory)
    {
        for (uint256 i = 1; i <= _level; i++) {
            left_child = calc_next_child(_number);
            sub_child_numbers = 2 ^ i;
            for (uint256 j = 0; j < sub_child_numbers; j++) {
                sub_child = left_child + j;
                childs.push(sub_child);
                _number = left_child;
            }
        }
        return childs;
    }

    // function

    // function get_last_partner_index() public view returns(uint256) {

    // }

    // function get_all_balances() public view returns (uint256[] memory) {
    //     for (uint256 i = 0; i < partnerCount; i++) {
    //         Partner storage partner = partnersByPositionId[i];
    //         balancesByPositionId[i] = partner.balance;
    //         return balancesByPositionId;
    //     }
    // }
}
