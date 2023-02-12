// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract gen {
    struct Partner {
        uint256 id;
        address wallet_addres;
        string ebr_code;
        string placement_id; // left or right of the upline
        uint256 balance;
    }
    mapping(uint256 => Partner) public partners;
    uint256[] public childrens;
    uint256 public partnerCount;
    uint256 public left_child;
    uint256 public right_child;

    constructor() public {
        partnerCount = 0;
    }

    function addPartner(
        address _wallet_address,
        string memory _ebr_code,
        string memory _placement_id,
        uint256 _balance
    ) public {
        partners[partnerCount] = Partner(
            partnerCount,
            _wallet_address,
            _ebr_code,
            _placement_id,
            _balance
        );
        partnerCount++;
    }

    function getPartner(uint256 _partnerId)
        public
        view
        returns (Partner memory)
    {
        return partners[_partnerId];
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

    function latest_user_index() public view returns (uint256) {
        uint256 last_index = partners.length - 1;
        return last_index;
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
// }
