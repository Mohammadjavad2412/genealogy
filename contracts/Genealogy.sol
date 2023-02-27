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
        address wallet_address;
        string ebr_code;
        string direction; // left or right of the upline
        uint256 balance;
        uint256 sum_left_balance;
        uint256 sum_right_balance;
        uint256 created_at;
        uint256 last_update;
        bool isValue;
    }
    mapping(uint256 => Partner) partnersByPositionId;
    mapping(address => Partner) partnersByWalletAddress;
    mapping(string => Partner) partnersByEbrCode;
    mapping(address => string[]) invitationLinksByreferallWalletAdress;
    mapping(address => string[]) invitationEbrPartnersByreferallWalletAddress;
    uint256[] Childs;
    string[] refferalCodes;
    uint256 position_id_from_ebr_code;
    uint256 partnerCount;
    uint256[] position_ids;
    uint256 upline_position_id;
    uint256 new_position_id;
    address StakingContract;
    address[] walletAddresses;

    constructor(string memory _admin_ebr_code, address stakeContractAddress)
        payable
    {
        partnerCount = 0;
        // addPartner(_admin_ebr_code, "none", "none");
        StakingContract = stakeContractAddress;
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

    function getDirectionByPositionId(uint256 _position_id) public view returns(string memory){
        if (_position_id%2==0){
            return "r";
        }
        else{
            return "l";
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
        require(userIsStaker(), "you should stake first!");
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
        string memory invited_ebr_code = parts[0];
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
        uint256 balance = MyStakingBalance();
        Partner memory partner = Partner(
            position_id,
            upline_position_id,
            msg.sender,
            invited_ebr_code,
            direction,
            balance,
            0,
            0,
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
    ) internal view returns (uint256) {
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
        string memory _upline_ebr_code
    ) public onlyOwner returns (string memory result) {
        require(userIsStaker(), "you should stake first");
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
        uint256 _balance = MyStakingBalance();
        Partner memory partner = Partner(
            new_position_id,
            upline_position_id,
            msg.sender,
            _ebr_code,
            _direction,
            _balance,
            0,
            0,
            block.timestamp,
            block.timestamp,
            true
        );
        partnersByEbrCode[_ebr_code] = partner;
        position_ids.push(new_position_id); // storing all position ids
        partnersByPositionId[new_position_id] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        walletAddresses.push(msg.sender);
        partnerCount++;
        result = "success";
        return result;
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
            wallet_address[i] = partner.wallet_address;
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
        if (_position_id==1 || _position_id==0){
            return 0;
        }
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

    function userIsStaker() public returns (bool result) {
        bytes memory payload = abi.encodeWithSignature(
            "isStakerByAddress(address)",
            msg.sender
        );
        (bool success, bytes memory returnData) = StakingContract.call(payload);
        bool result = abi.decode(returnData, (bool));
        return result;
    }

    function stakingBalance(address _staker_addr)
        public
        onlyOwner
        returns (uint256)
    {
        bytes memory payload = abi.encodeWithSignature(
            "BalanceOf(address)",
            _staker_addr
        );
        (bool success, bytes memory returnData) = StakingContract.call(payload);
        uint256 balance = abi.decode(returnData, (uint256));
        return balance;
    }

    function MyStakingBalance() public returns (uint256) {
        bytes memory payload = abi.encodeWithSignature(
            "BalanceOf(address)",
            msg.sender
        );
        (bool success, bytes memory returnData) = StakingContract.call(payload);
        uint256 balance = abi.decode(returnData, (uint256));
        return balance;
    }

    function updateBalance(address _wallet_address)
        internal
        onlyOwner
        returns (uint256)
    {
        Partner memory partner = partnersByWalletAddress[_wallet_address];
        uint256 new_balance = stakingBalance(_wallet_address);
        partner.balance = new_balance;
        return new_balance;
    }

    function updateBalances() public onlyOwner {
        for (uint256 i = 0; i < walletAddresses.length; i++) {
            updateBalance(walletAddresses[i]);
        }
    }

    function calcLeftRightChildBalance(uint256 _position_id)
        public
        returns (uint256, uint256)
    {
        uint256 left_child_position = _position_id * 2 + 1;
        uint256 right_child_position = _position_id * 2 + 2;
        Partner memory left_partner = partnersByPositionId[left_child_position];
        Partner memory right_partner = partnersByPositionId[
            right_child_position
        ];
        address left_partner_wallet_address = left_partner.wallet_address;
        address right_partner_wallet_address = right_partner.wallet_address;
        uint256 left_partner_staked_balance = stakingBalance(
            left_partner_wallet_address
        );
        uint256 right_partner_staked_balance = stakingBalance(
            right_partner_wallet_address
        );
        return (left_partner_staked_balance, right_partner_staked_balance);
    }

    function updatePartner(Partner memory partner)internal onlyOwner{
        address wallet_address = partner.wallet_address;
        uint256 position_id = partner.position_id;
        string memory ebr_code = partner.ebr_code;
        partnersByPositionId[position_id]=partner;
        partnersByWalletAddress[wallet_address]=partner;
        partnersByEbrCode[ebr_code]=partner;
    }

    function updateUplinesBalances(uint256 _position_id,uint256 amount)public onlyOwner{
        require(isValidPositionId(_position_id),"invalid postion id");
        bool not_done =true;
        uint256 up_line_position_id = calcUplineFromPositionId(_position_id);
        while (not_done){
            Partner memory partner = partnersByPositionId[upline_position_id];
            if (keccak256(abi.encodePacked(getDirectionByPositionId(_position_id)))==keccak256(abi.encodePacked("r"))){
                uint256 old_balance = partner.sum_right_balance;
                uint256 new_balance = old_balance + amount;
                partner.sum_right_balance = new_balance;
                updatePartner(partner);
            }
            else{
                uint256 old_balance = partner.sum_left_balance;
                uint256 new_balance = old_balance + amount;
                partner.sum_left_balance = new_balance;
                updatePartner(partner);
            }
            uint256 _position_id = upline_position_id;
            uint256 upline_position_id = calcUplineFromPositionId(upline_position_id);
            if (_position_id ==0 && upline_position_id == 0){
                not_done = false;
            }
        }
    }

    function calc_next_child(uint256 _number) public returns(uint256) {
        uint256 left_child = _number * 2 + 1;
        return left_child;
    }
    
    function calc_childs(uint256 _number, uint256 _level) public returns(uint256[] memory) {
        for (uint256 i = 1; i <= _level; i++) {
            uint256 left_child = calc_next_child(_number);
            uint256 sub_child_numbers = 2 ** i;
            for (uint256 j = 0; j < sub_child_numbers; j++) {
                uint256 sub_child = left_child + j;
                Childs.push(sub_child);
            _number = left_child;
            }
        }
        return Childs;
    }
}
