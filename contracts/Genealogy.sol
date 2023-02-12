// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Genealogy {
    struct Partner {
        uint256 position_id;
        address wallet_addres;
        string ebr_code;
        string direction; // left or right of the upline
        uint256 balance;
        uint256 created_at;
        uint256 last_update;
    }

    mapping(uint256 => Partner) public partnersByPositionId;
    mapping(string => Partner) public  partnersByWalletAddress;
    mapping(string => Partner) public partnersByEbrCode;
    uint256 public partnerCount;

    constructor() {
        partnerCount = 0;
    }

    function isValidEbrCode(uint256 _ebr_code) public {
        if (partnersByEbrCode[_ebr_code]){
            return true;
        }
        else{
            return false;
        }
    }

    function isValidPositionId(uint256 _position_id) public {
        if (partnersByPositionId[_position_id]){
            return true;
        }
        else{
            return false;
        }
    }

    function isValidDirection(string _direction) public {
        if (_direction=='r' | _direction == 'l'){
            return true;
        }
        else{
            return false;
        }
    }

    function generatePositionId(uint256 _upline_postion_id,string _direction) public {
        if (isValidDirection(_direction)){
            if (isValidPositionId(_upline_postion_id)==true){
                if (_direction == 'r'){
                    return _upline_postion_id*2+2;
                }
                else{
                    return _upline_postion_id*2+1;
                }
            }
            else{
                return "invalid upline position_id";
            }
        }
        else{
            return "invalid direction passed. direction should be r or l (r for right and l for left)";
        }
    }

    function getPositionIdFromEbrCode(uint256 _ebr_code)public{
        if (isValidEbrCode(_ebr_code)){
            partner = partnersByEbrCode[_ebr_code];
            return partner.position_id;
        }
    }

    function addPartner(
        string storage _ebr_code,
        string storage _direction,
        string storage _upline_ebr_code,
        uint256 storage _balance
    ) public {
        uint256 upline_position_id = getPositionIdFromEbrCode(_upline_ebr_code);
        uint256 new_position_id = generatePositionId(_upline_postion_id, _direction);
        partnersByPositionId[partnerCount] = Partner(
            partnerCount,
            msg.sender,
            _ebr_code,
            _placement_id,
            _balance
        );
        partnerCount++;
    }

    function getPartner(uint256 _postion_id)
        public
        view
        returns (Partner memory)
    {
        return partnersByPositionId[_partnerId];
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
        string[] memory placement_id = new string[](partnerCount);
        uint256[] memory balance = new uint256[](partnerCount);
        for (uint256 i = 0; i < partnerCount; i++) {
            Partner storage partner = partners[i];
            id[i] = partner.id;
            wallet_address[i] = partner.wallet_addres;
            ebr_code[i] = partner.ebr_code;
            placement_id[i] = partner.placement_id;
            balance[i] = partner.balance;
        }
        return (id, wallet_address, ebr_code, placement_id, balance);
    }

//     function get_childs(uint256 _number)
//         public
//         view
//         returns (uint256[] memory)
//     {
//         uint256[] memory childs = new uint256[]();
//         (left_child, right_child) = calc_next_childs(_number);
//         (l_left_child, l_right_child) = calc_next_childs(left_child);
//         (r_left_child, r_right_child) = calc_next_childs(right_child);
//     }

//     function calc_next_childs(uint256 _number)
//         public
//         view
//         returns (uint256 memory, uint256 memory)
//     {
//         uint256[] memory childs = new uint256[]();
//         left_child = (_number * 2) + 1;
//         right_child = (_number * 2) + 2;
//         return (left_child, right_child);
//     }
}
