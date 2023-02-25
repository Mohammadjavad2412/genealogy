// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Strings.sol";
import "github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Genealogy is Ownable, ReentrancyGuard {
    using strings for *;
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
    mapping(uint256 => Partner) partnersByPositionId;
    mapping(address => Partner) partnersByWalletAddress;
    mapping(string => Partner) partnersByEbrCode;
    mapping(address => string[]) invitationLinksByreferallWalletAdress;
    mapping(address => string[]) invitationEbrPartnersByreferallWalletAddress;
    string[] refferalCodes;
    uint256 left_child;
    uint256 sub_child_numbers;
    uint256 sub_child;
    uint256 position_id_from_ebr_code;
    mapping(string => Partner) Childs;
    uint256 partnerCount;
    uint256[] position_ids;
    uint256 upline_position_id;
    uint256 new_position_id;

    constructor(string memory _admin_ebr_code) payable {
        partnerCount = 0;
        // string memory admin_ebr_code = Strings.toString(_admin_ebr_code);
        addPartner(_admin_ebr_code, "none", "none", 100);
    }

    function isValidEbrCode(string memory _ebr_code)
        internal
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
        internal
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
        internal
        pure
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

    function IsValidEbrCode(string memory _ebr_code)
        internal
        view
        returns (bool)
    {
        if (partnersByEbrCode[_ebr_code].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function createReffralString(
        string memory _invitation_ebr_code,
        string memory _refferal_ebr_code,
        uint256 _position_id
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    _invitation_ebr_code,
                    "-",
                    _refferal_ebr_code,
                    "-",
                    Strings.toString(_position_id),
                    "-"
                )
            );
    }

    function addRefferalCode(string memory _refferalCode) internal {
        refferalCodes.push(_refferalCode);
    }

    function addInvitaionLinksByWalletAddress(string memory _refferalLink)
        internal
    {
        invitationLinksByreferallWalletAdress[msg.sender].push(_refferalLink);
    }

    function addInvitationEbrCodesByWalletAddress(
        string memory _invitation_code
    ) internal {
        invitationEbrPartnersByreferallWalletAddress[msg.sender].push(
            _invitation_code
        );
    }

    function isValidWalletAddress() public view returns (bool) {
        address sender = msg.sender;
        if (partnersByWalletAddress[sender].isValue == true) {
            return true;
        } else {
            return false;
        }
    }

    function myInvitationLinks() public view returns (string[] memory) {
        return invitationLinksByreferallWalletAdress[msg.sender];
    }

    function myInvitationEbrsPartner() public view returns (string[] memory) {
        return invitationEbrPartnersByreferallWalletAddress[msg.sender];
    }

    function isValidInvitationLink(string memory _invitation_link)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < refferalCodes.length; i++) {
            if (
                keccak256(abi.encodePacked(refferalCodes[i])) ==
                keccak256(abi.encodePacked(_invitation_link))
            ) {
                return true;
            }
        }
        return false;
    }

    function createRefferalCode(
        string memory _invitation_ebr_code,
        uint256 _position_id
    ) public returns (string memory) {
        require(
            IsValidEbrCode(_invitation_ebr_code) == false,
            "duplicate ebr code!"
        );
        uint256 _upline = calcUplineFromPositionId(_position_id);
        require(
            isValidPositionId(_upline),
            "invalid position id.Are you sure that has upline?"
        );
        require(
            isValidPositionId(_position_id) == false,
            "this position is already filled!"
        );
        Partner memory refferal_partner = partnersByWalletAddress[msg.sender];
        string memory refferalCode = createReffralString(
            _invitation_ebr_code,
            refferal_partner.ebr_code,
            _position_id
        );
        addInvitaionLinksByWalletAddress(refferalCode);
        addInvitationEbrCodesByWalletAddress(_invitation_ebr_code);
        refferalCodes.push(refferalCode);
        return refferalCode;
    }

    function addPartnerFromLink(string memory _invitation_link)
        public
        returns (string memory result)
    {
        string memory direction;
        string memory invitation_link = _invitation_link;
        require(isValidWalletAddress() == false, "you had position.");
        require(
            isValidInvitationLink(invitation_link),
            "invalid invitation link"
        );
        strings.slice memory s = invitation_link.toSlice();
        strings.slice memory delim = "-".toSlice();
        string[] memory parts = new string[](s.count(delim));
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
        }
        // require(parts.length==3,"invalid ebr code");
        string memory invited_ebr_code = parts[0];
        string memory refferal_ebr_code = parts[1];
        uint256 position_id = stringToUint(parts[2]);
        require(
            isValidPositionId(position_id) == false,
            "this position is already filled"
        );
        uint256 upline_position_id = calcUplineFromPositionId(position_id);
        string memory upline_ebr_code = partnersByPositionId[upline_position_id]
            .ebr_code;
        if (position_id % 2 == 0) {
            string memory direction = "r";
        } else {
            string memory direction = "l";
        }

        Partner memory partner = Partner(
            position_id,
            upline_position_id,
            msg.sender,
            invited_ebr_code,
            direction,
            1,
            block.timestamp,
            block.timestamp,
            true
        );
        partnersByEbrCode[invited_ebr_code] = partner;
        position_ids.push(position_id);
        partnersByPositionId[position_id] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        partnerCount++;
        return "successfully add partner";
    }

    function generatePositionId(
        uint256 _upline_postion_id,
        string memory _direction
    ) internal returns (uint256) {
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
            return _upline_postion_id * 2 + 2;
        } else {
            return _upline_postion_id * 2 + 1;
        }
    }

    function getPositionIdFromEbrCode(string memory _ebr_code)
        public
        onlyOwner
        returns (string memory)
    {
        if (isValidEbrCode(_ebr_code) == true) {
            Partner storage partner = partnersByEbrCode[_ebr_code];
            position_id_from_ebr_code = partner.position_id;
            return Strings.toString(position_id_from_ebr_code);
        } else {
            return "none";
        }
    }

    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }

    function addPartner(
        string memory _ebr_code,
        string memory _direction,
        string memory _upline_ebr_code,
        uint256 _balance
    ) internal returns (uint256[] memory) {
        if (
            keccak256(abi.encodePacked(_upline_ebr_code)) ==
            keccak256(abi.encodePacked("none"))
        ) {
            upline_position_id = 0;
            new_position_id = 0;
        } else {
            uint256 upline_position_id = stringToUint(
                getPositionIdFromEbrCode(_upline_ebr_code)
            );
            uint256 new_position_id = generatePositionId(
                upline_position_id,
                _direction
            );
        }

        Partner memory partner = Partner(
            new_position_id,
            upline_position_id,
            msg.sender,
            _ebr_code,
            _direction,
            _balance,
            block.timestamp,
            block.timestamp,
            true
        );
        partnersByEbrCode[_ebr_code] = partner;
        position_ids.push(new_position_id); // storing all position ids
        partnersByPositionId[new_position_id] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        partnerCount++;
    }

    function getPositionIdList() internal view returns (uint256[] memory) {
        return position_ids;
    }

    function countPositionIds() internal view returns (uint256) {
        return position_ids.length;
    }

    function getPartner(uint256 _position_id)
        public
        view
        onlyOwner
        returns (Partner memory)
    {
        require(isValidPositionId(_position_id), "invalid position id");
        return partnersByPositionId[_position_id];
    }

    function getPartners()
        internal
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
        for (uint256 i = 0; i < position_ids.length; i++) {
            uint256 j = position_ids[i];
            Partner memory partner = partnersByPositionId[j];
            id[i] = partner.position_id;
            wallet_address[i] = partner.wallet_addres;
            ebr_code[i] = partner.ebr_code;
            direction[i] = partner.direction;
            balance[i] = partner.balance;
        }
        return (id, wallet_address, ebr_code, direction, balance);
    }

    function calcNextChilds(uint256 _position_id)
        public
        pure
        returns (uint256, uint256)
    {
        uint256 left_child_position = _position_id * 2 + 1;
        uint256 right_child_position = _position_id * 2 + 2;
        return (left_child_position, right_child_position);
    }

    function calcUplineFromPositionId(uint256 _position_id)
        public
        pure
        returns (uint256)
    {
        if (_position_id % 2 == 0) {
            return (_position_id - 2) / 2;
        } else {
            return (_position_id - 1) / 2;
        }
    }

    function getBalanceByPositionId(uint256 _position_id)
        public
        view
        onlyOwner
        returns (uint256)
    {
        Partner memory partner = partnersByPositionId[_position_id];
        require(isValidPositionId(_position_id), "invalid position id");
        return partner.balance;
    }
}
