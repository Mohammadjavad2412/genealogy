// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "github.com/Arachnid/solidity-stringutils/blob/master/src/strings.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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
        uint256 childs_count;
        uint256 full_fill_level;
        uint256 created_at;
        uint256 last_update;
        bool isValue;
    }

    function log_2(uint256 number) internal pure returns (uint8) {
        require(number > 0, "0");
        for (uint8 n = 0; n < 256; n++) {
            if (number >= 2 ** n && number < 2 ** (n + 1)) {
                return n;
            }
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

    struct TransactionsLog {
        address from;
        uint256 amount;
        string transaction_type;
        uint256 timestamp;
    }

    mapping(uint256 => Partner) public partnersByPositionId;
    mapping(address => Partner) partnersByWalletAddress;
    mapping(string => Partner) partnersByEbrCode;
    mapping(address => TransactionsLog[]) transactionLogsByAddress;
    mapping(address => string[]) invitationLinksByreferallWalletAdress;
    mapping(address => string[]) invitationEbrPartnersByreferallWalletAddress;
    uint256[] Childs;
    uint256[] assume_full_fill_level_partners;
    uint256[] each_level_childs_number;
    string[] refferalCodes;
    uint256 position_id_from_ebr_code;
    uint256 partnerCount;
    uint256[] public position_ids;
    uint256 upline_position_id;
    address _owner;
    uint256 new_position_id;
    address public StakingContractAddress;
    address public DappTokenContractAddress;
    address[] walletAddresses;

    constructor(
        address stakeContractAddress,
        address dappTokenContractAddress
    ) payable {
        _owner = msg.sender;
        StakingContractAddress = stakeContractAddress;
        DappTokenContractAddress = dappTokenContractAddress;
        Partner memory partner = Partner(
            0,
            0,
            msg.sender,
            "admin",
            "none",
            0,
            0,
            0,
            0,
            0,
            block.timestamp,
            block.timestamp,
            true
        );
        partnersByEbrCode["admin"] = partner;
        position_ids.push(0);
        partnersByPositionId[0] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        walletAddresses.push(msg.sender);
        partnerCount = 1;
    }

    function isValidEbrCode(
        string memory _ebr_code
    ) internal view returns (bool) {
        if (partnersByEbrCode[_ebr_code].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function isValidPositionId(
        uint256 _position_id
    ) internal view returns (bool) {
        if (partnersByPositionId[_position_id].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function isValidDirection(
        string memory _direction
    ) internal pure returns (bool) {
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

    function getDirectionByPositionId(
        uint256 _position_id
    ) internal view returns (string memory) {
        if (_position_id % 2 == 0) {
            return "r";
        } else {
            return "l";
        }
    }

    function IsValidEbrCode(
        string memory _ebr_code
    ) internal view returns (bool) {
        if (partnersByEbrCode[_ebr_code].isValue) {
            return true;
        } else {
            return false;
        }
    }

    function addRefferalCode(string memory _refferalCode) internal {
        refferalCodes.push(_refferalCode);
    }

    function addInvitaionLinksByWalletAddress(
        string memory _refferalLink
    ) internal {
        invitationLinksByreferallWalletAdress[msg.sender].push(_refferalLink);
    }

    function addInvitationEbrCodesByWalletAddress(
        string memory _invitation_code
    ) internal {
        invitationEbrPartnersByreferallWalletAddress[msg.sender].push(
            _invitation_code
        );
    }

    function isValidWalletAddress() internal view returns (bool) {
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

    function isValidInvitationLink(
        string memory _invitation_link
    ) internal view returns (bool) {
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
        require(IsValidEbrCode(_invitation_ebr_code) == false, "1");
        uint256 _upline = calcUplineFromPositionId(_position_id);
        require(isValidPositionId(_upline), "2");
        require(isValidPositionId(_position_id) == false, "3");
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

    function addPartnerFromLink(
        string memory _invitation_link
    ) public // returns (string memory result)
    {
        require(userIsStaker(), "4");
        string memory direction;
        string memory invitation_link = _invitation_link;
        require(isValidWalletAddress() == false, "5");
        require(isValidInvitationLink(invitation_link), "1");
        strings.slice memory s = invitation_link.toSlice();
        strings.slice memory delim = "-".toSlice();
        string[] memory parts = new string[](s.count(delim));
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
        }

        string memory invited_ebr_code = parts[0];
        uint256 position_id = stringToUint(parts[2]);
        require(isValidPositionId(position_id) == false, "1");
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
            0,
            0,
            block.timestamp,
            block.timestamp,
            true
        );
        // referral bonus
        uint256 _amount = (balance * 1) / 10;
        string memory _ebr_code = parts[1];
        Partner memory _referrer_partner = partnersByEbrCode[_ebr_code];
        address _referrer_partner_address = _referrer_partner.wallet_address;
        transferFromDappContract(_referrer_partner_address, _amount);
        referralBonusLogs(msg.sender, _referrer_partner_address, _amount);
        partnersByEbrCode[invited_ebr_code] = partner;
        position_ids.push(position_id);
        partnersByPositionId[position_id] = partner;
        partnersByWalletAddress[msg.sender] = partner;
        updateUplinesChildsCount(position_id);
        updateUplinesFullFillLevel(position_id);
        partnerCount++;
        // return "successfully add partner";
    }

    function generatePositionId(
        uint256 _upline_postion_id,
        string memory _direction
    ) internal view returns (uint256) {
        require(isValidDirection(_direction) == true, "6");
        require(isValidPositionId(_upline_postion_id) == true, "2");
        if (
            keccak256(abi.encodePacked(_direction)) ==
            keccak256(abi.encodePacked("r"))
        ) {
            return _upline_postion_id * 2 + 2;
        } else {
            return _upline_postion_id * 2 + 1;
        }
    }

    function getPositionIdFromEbrCode(
        string memory _ebr_code
    ) internal onlyOwner returns (string memory) {
        if (isValidEbrCode(_ebr_code) == true) {
            Partner storage partner = partnersByEbrCode[_ebr_code];
            position_id_from_ebr_code = partner.position_id;
            return Strings.toString(position_id_from_ebr_code);
        } else {
            return "none";
        }
    }

    function getPositionIdList() internal view returns (uint256[] memory) {
        return position_ids;
    }

    function countPositionIds() internal view returns (uint256) {
        return position_ids.length;
    }

    function getPartner(
        uint256 _position_id
    ) internal view onlyOwner returns (Partner memory) {
        require(isValidPositionId(_position_id), "3");
        return partnersByPositionId[_position_id];
    }

    // function calcNextChilds(uint256 _position_id)
    //     public
    //     pure
    //     returns (uint256, uint256)
    // {
    //     uint256 left_child_position = _position_id * 2 + 1;
    //     uint256 right_child_position = _position_id * 2 + 2;
    //     return (left_child_position, right_child_position);
    // }

    function calcUplineFromPositionId(
        uint256 _position_id
    ) internal pure returns (uint256) {
        if (_position_id == 1 || _position_id == 0) {
            return 0;
        }
        if (_position_id % 2 == 0) {
            return (_position_id - 2) / 2;
        } else {
            return (_position_id - 1) / 2;
        }
    }

    function getBalanceByPositionId(
        uint256 _position_id
    ) internal view onlyOwner returns (uint256) {
        Partner memory partner = partnersByPositionId[_position_id];
        require(isValidPositionId(_position_id), "3");
        return partner.balance;
    }

    function userIsStaker() internal returns (bool result) {
        bytes memory payload = abi.encodeWithSignature(
            "isStakerByAddress(address)",
            msg.sender
        );
        (bool success, bytes memory returnData) = StakingContractAddress.call(
            payload
        );
        bool result = abi.decode(returnData, (bool));
        return result;
    }

    function stakingBalance(
        address _staker_addr
    ) internal onlyOwner returns (uint256) {
        bytes memory payload = abi.encodeWithSignature(
            "BalanceOf(address)",
            _staker_addr
        );
        (bool success, bytes memory returnData) = StakingContractAddress.call(
            payload
        );
        uint256 balance = abi.decode(returnData, (uint256));
        return balance;
    }

    function MyStakingBalance() internal returns (uint256) {
        bytes memory payload = abi.encodeWithSignature(
            "BalanceOf(address)",
            msg.sender
        );
        (bool success, bytes memory returnData) = StakingContractAddress.call(
            payload
        );
        uint256 balance = abi.decode(returnData, (uint256));
        return balance;
    }

    function updateBalance(
        address _wallet_address
    ) internal onlyOwner returns (uint256) {
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

    function updatePartner(Partner memory partner) internal {
        address wallet_address = partner.wallet_address;
        uint256 position_id = partner.position_id;
        string memory ebr_code = partner.ebr_code;
        partner.last_update = block.timestamp;
        partnersByPositionId[position_id] = partner;
        partnersByWalletAddress[wallet_address] = partner;
        partnersByEbrCode[ebr_code] = partner;
    }

    function updateUplinesBalances(
        uint256 _position_id,
        uint256 amount
    ) public onlyOwner {
        require(isValidPositionId(_position_id), "3");
        bool not_done = true;
        uint256 upline_position_id = calcUplineFromPositionId(_position_id);
        if (_position_id == 1 || _position_id == 2) {
            Partner memory partner = partnersByPositionId[0];
            if (_position_id == 1) {
                uint256 old_balance = partner.sum_left_balance;
                uint256 new_balance = old_balance + amount;
                partner.sum_left_balance = new_balance;
                updatePartner(partner);
            } else {
                uint256 old_balance = partner.sum_right_balance;
                uint256 new_balance = old_balance + amount;
                partner.sum_right_balance = new_balance;
                updatePartner(partner);
            }
        } else {
            while (not_done) {
                Partner memory partner = partnersByPositionId[
                    upline_position_id
                ];
                if (
                    keccak256(
                        abi.encodePacked(getDirectionByPositionId(_position_id))
                    ) == keccak256(abi.encodePacked("r"))
                ) {
                    uint256 old_balance = partner.sum_right_balance;
                    uint256 new_balance = old_balance + amount;
                    partner.sum_right_balance = new_balance;
                    updatePartner(partner);
                } else {
                    uint256 old_balance = partner.sum_left_balance;
                    uint256 new_balance = old_balance + amount;
                    partner.sum_left_balance = new_balance;
                    updatePartner(partner);
                }
                uint256 previous_position_id = upline_position_id;
                uint256 upline_position_id = calcUplineFromPositionId(
                    upline_position_id
                );
                uint256 _position_id = upline_position_id;
                if (_position_id == 0 && upline_position_id == 0) {
                    Partner memory partner = partnersByPositionId[0];
                    if (previous_position_id == 1) {
                        uint256 old_balance = partner.sum_left_balance;
                        uint256 new_balance = old_balance + amount;
                        partner.sum_left_balance = new_balance;
                        updatePartner(partner);
                    } else {
                        uint256 old_balance = partner.sum_right_balance;
                        uint256 new_balance = old_balance + amount;
                        partner.sum_right_balance = new_balance;
                        updatePartner(partner);
                    }
                    not_done = false;
                }
            }
        }
    }

    function updateUplinesChildsCount(uint256 _position_id) internal {
        require(isValidPositionId(_position_id), "3");
        bool not_done = true;
        uint256 upline_position_id = calcUplineFromPositionId(_position_id);
        if (_position_id == 1 || _position_id == 2) {
            Partner memory partner = partnersByPositionId[0];
            uint256 old_child_count = partner.childs_count;
            uint256 new_child_count = old_child_count + 1;
            partner.childs_count = new_child_count;
            updatePartner(partner);
        } else {
            while (not_done) {
                Partner memory partner = partnersByPositionId[
                    upline_position_id
                ];
                uint256 old_child_count = partner.childs_count;
                uint256 new_child_count = old_child_count + 1;
                partner.childs_count = new_child_count;
                updatePartner(partner);
                uint256 upline_position_id = calcUplineFromPositionId(
                    upline_position_id
                );
                uint256 _position_id = upline_position_id;
                if (_position_id == 0 && upline_position_id == 0) {
                    Partner memory partner = partnersByPositionId[0];
                    uint256 old_child_count = partner.childs_count;
                    uint256 new_child_count = old_child_count + 1;
                    partner.childs_count = new_child_count;
                    updatePartner(partner);
                    not_done = false;
                }
            }
        }
    }

    function calcFirstLeftChild(uint256 _number) internal returns (uint256) {
        uint256 left_child = _number * 2 + 1;
        return left_child;
    }

    function getChildsByLevel(
        uint256 _position_id,
        uint256 _level
    ) public returns (uint256[] memory) {
        delete Childs;
        for (uint256 i = 1; i <= _level; i++) {
            uint256 left_child = calcFirstLeftChild(_position_id);
            uint256 sub_child_numbers = 2 ** i;
            for (uint256 j = 0; j < sub_child_numbers; j++) {
                uint256 sub_child = left_child + j;
                Childs.push(sub_child);
                _position_id = left_child;
            }
        }
        return Childs;
    }

    function getChildsCountByLevel(uint256 _level) internal returns (uint256) {
        delete each_level_childs_number;
        uint256 result;
        for (uint256 i = 1; i <= _level; i++) {
            uint256 _level_childs_number = 2 ** i;
            each_level_childs_number.push(_level_childs_number);
        }
        for (uint256 i = 0; i < each_level_childs_number.length; i++) {
            uint256 previous_result = each_level_childs_number[i];
            result = previous_result + result;
        }
        return result;
    }

    function getFullLevelByChildsCount(
        uint256 _childs_number
    ) internal returns (uint256 result) {
        uint256 result = log_2(_childs_number);
        return result;
    }

    function getChildsInSpecificLevel(
        uint256 _position_id,
        uint256 _level
    ) internal returns (uint256[] memory) {
        delete Childs;
        if (_level == 0) {
            Childs.push(_position_id);
            return Childs;
        }
        for (uint256 i = 1; i <= _level; i++) {
            uint256 left_child = calcFirstLeftChild(_position_id);
            _position_id = left_child;
            if (i == _level) {
                uint256 sub_child_numbers = 2 ** i;
                for (uint256 j = 0; j < sub_child_numbers; j++) {
                    uint256 sub_child = left_child + j;
                    Childs.push(sub_child);
                }
                return Childs;
            }
        }
    }

    function FullFillLevel(uint256 _position_id) internal returns (uint256) {
        delete assume_full_fill_level_partners;
        Partner memory partner = partnersByPositionId[_position_id];
        uint256 childs_count = partner.childs_count;
        if (childs_count == 0) {
            return 0;
        }
        bool not_done = true;
        uint256 assume_full_fill_level = getFullLevelByChildsCount(
            childs_count
        );
        while (not_done) {
            assume_full_fill_level_partners = getChildsInSpecificLevel(
                _position_id,
                assume_full_fill_level
            );
            for (
                uint256 i = 0;
                i < assume_full_fill_level_partners.length;
                i++
            ) {
                Partner memory child_partner = partnersByPositionId[
                    assume_full_fill_level_partners[i]
                ];
                if (child_partner.isValue == false) {
                    assume_full_fill_level = assume_full_fill_level - 1;
                }
            }
            not_done = false;
        }
        uint256 full_fill_level = assume_full_fill_level;
        return full_fill_level;
    }

    function updateUplinesFullFillLevel(uint256 _position_id) internal {
        require(isValidPositionId(_position_id), "3");
        bool not_done = true;
        uint256 upline_position_id = calcUplineFromPositionId(_position_id);
        if (_position_id == 1 || _position_id == 2) {
            Partner memory partner = partnersByPositionId[0];
            uint256 old_level = partner.full_fill_level;
            uint256 new_level = FullFillLevel(0);
            partner.full_fill_level = new_level;
            updatePartner(partner);
        } else {
            while (not_done) {
                Partner memory partner = partnersByPositionId[
                    upline_position_id
                ];
                uint256 old_level = partner.full_fill_level;
                uint256 new_level = FullFillLevel(0);
                partner.full_fill_level = new_level;
                updatePartner(partner);
                uint256 upline_position_id = calcUplineFromPositionId(
                    upline_position_id
                );
                uint256 _position_id = upline_position_id;
                if (_position_id == 0 && upline_position_id == 0) {
                    Partner memory partner = partnersByPositionId[0];
                    uint256 old_level = partner.full_fill_level;
                    uint256 new_level = FullFillLevel(0);
                    partner.full_fill_level = new_level;
                    updatePartner(partner);
                    not_done = false;
                }
            }
        }
    }

    function transferFromDappContract(address _to, uint256 _amount) internal {
        IERC20(DappTokenContractAddress).transfer(_to, _amount);
    }

    function calcPartnerStakingReward(
        address _staker_addr
    ) internal returns (uint256) {
        bytes memory payload = abi.encodeWithSignature(
            "calculateRewardsByAddress(address)",
            _staker_addr
        );
        (bool success, bytes memory returnData) = StakingContractAddress.call(
            payload
        );
        uint256 reward = abi.decode(returnData, (uint256));
        return reward;
    }

    function calcUplinesPositionIdsFromPositionId(
        uint256 _position_id
    ) internal returns (uint256[] memory) {
        delete Childs;
        require(isValidPositionId(_position_id), "3");
        bool not_done = true;
        while (not_done) {
            uint256 _upline_postion_id = calcUplineFromPositionId(_position_id);
            Childs.push(_upline_postion_id);
            _position_id = _upline_postion_id;
            if (_position_id == 0) {
                not_done = false;
            }
        }
        return Childs;
    }

    function updateUplinesUniLevelRewards(
        uint256 _position_id
    ) public payable onlyOwner {
        require(isValidPositionId(_position_id), "3");
        bool not_done = true;
        while (not_done) {
            Partner memory partner = partnersByPositionId[_position_id];
            address partner_wallet_address = partner.wallet_address;
            uint256 _reward = getStakerRewardsUpToNow(partner_wallet_address) /
                100;
            uint256[]
                memory _upline_position_ids = calcUplinesPositionIdsFromPositionId(
                    _position_id
                );
            for (uint256 i = 0; i < _upline_position_ids.length; i++) {
                if (i < 20) {
                    Partner
                        memory one_of_upline_partners = partnersByPositionId[
                            _upline_position_ids[i]
                        ];
                    address one_of_upline_partners_wallet_address = one_of_upline_partners
                            .wallet_address;
                    transferFromDappContract(
                        one_of_upline_partners_wallet_address,
                        _reward
                    );
                    TransactionsLog memory transactionslog = TransactionsLog(
                        partner_wallet_address,
                        _reward,
                        "uni_level_bonus",
                        block.timestamp
                    );
                    transactionLogsByAddress[
                        one_of_upline_partners_wallet_address
                    ].push(transactionslog);
                }
            }
            _position_id = calcUplineFromPositionId(_position_id);
            if (_position_id == 0) {
                not_done = false;
            }
        }
    }

    function getStakerRewardsUpToNow(
        address _staker_addr
    ) internal returns (uint256) {
        bytes memory payload = abi.encodeWithSignature(
            "InitialBalance(address)",
            _staker_addr
        );
        (bool success, bytes memory returnData) = StakingContractAddress.call(
            payload
        );
        uint256 _reward = abi.decode(returnData, (uint256)) / 10;
        return _reward;
    }

    function binaryBonus() public onlyOwner {
        for (uint256 i = 0; i < position_ids.length; i++) {
            Partner memory partner = partnersByPositionId[position_ids[i]];
            address partner_wallet_address = partner.wallet_address;
            uint256 left_balance = partner.sum_left_balance;
            uint256 right_balance = partner.sum_right_balance;
            if (left_balance < right_balance) {
                uint256 binary_reward = left_balance / 10;
                matchingBonus(position_ids[i], binary_reward);
                transferFromDappContract(partner_wallet_address, binary_reward);
                TransactionsLog memory transactionslog = TransactionsLog(
                    partner_wallet_address,
                    binary_reward,
                    "binary_reward",
                    block.timestamp
                );
                transactionLogsByAddress[partner_wallet_address].push(
                    transactionslog
                );
                uint256 left_and_right_balance_difference = right_balance -
                    left_balance;
                partner.sum_left_balance = 0;
                partner.sum_right_balance = left_and_right_balance_difference;
                updatePartner(partner);
            } else {
                uint256 binary_reward = right_balance / 10;
                matchingBonus(position_ids[i], binary_reward);
                transferFromDappContract(partner_wallet_address, binary_reward);
                TransactionsLog memory transactionslog = TransactionsLog(
                    partner_wallet_address,
                    binary_reward,
                    "binary_reward",
                    block.timestamp
                );
                transactionLogsByAddress[partner_wallet_address].push(
                    transactionslog
                );
                uint256 left_and_right_balance_difference = left_balance -
                    right_balance;
                partner.sum_left_balance = left_and_right_balance_difference;
                partner.sum_right_balance = 0;
                updatePartner(partner);
            }
        }
        // return "binary and matching bonuses shared successfully.";
    }

    function matchingBonus(
        uint256 _position_id,
        uint256 _binary_reward
    ) internal onlyOwner {
        uint256 _level_one_reward = (_binary_reward * 5) / 100;
        uint256 _level_two_reward = (_binary_reward * 3) / 100;
        uint256 _level_three_reward = (_binary_reward * 2) / 100;
        if (_binary_reward != 0) {
            if (_position_id > 0) {
                uint256 _first_upline = calcUplineFromPositionId(_position_id);
                Partner memory _first_upline_partner = partnersByPositionId[
                    _first_upline
                ];
                address _first_upline_partner_wallet_address = _first_upline_partner
                        .wallet_address;
                transferFromDappContract(
                    _first_upline_partner_wallet_address,
                    _level_one_reward
                );
                address _behalf_of = partnersByPositionId[_position_id]
                    .wallet_address;
                TransactionsLog memory transactionslog = TransactionsLog(
                    _behalf_of,
                    _level_one_reward,
                    "matching_bonus_being_level_one",
                    block.timestamp
                );
                transactionLogsByAddress[_first_upline_partner_wallet_address]
                    .push(transactionslog);
                if (_position_id > 2) {
                    uint256 _second_upline = calcUplineFromPositionId(
                        _first_upline
                    );
                    Partner
                        memory _second_upline_partner = partnersByPositionId[
                            _second_upline
                        ];
                    address _second_upline_partner_wallet_address = _second_upline_partner
                            .wallet_address;
                    transferFromDappContract(
                        _second_upline_partner_wallet_address,
                        _level_two_reward
                    );
                    TransactionsLog memory transactionslog = TransactionsLog(
                        _behalf_of,
                        _level_two_reward,
                        "mathing_bonus_being_level_two",
                        block.timestamp
                    );
                    transactionLogsByAddress[
                        _second_upline_partner_wallet_address
                    ].push(transactionslog);
                    if (_position_id > 6) {
                        uint256 _third_upline = calcUplineFromPositionId(
                            _second_upline
                        );
                        Partner
                            memory _third_upline_partner = partnersByPositionId[
                                _third_upline
                            ];
                        address _third_upline_partner_wallet_address = _third_upline_partner
                                .wallet_address;
                        transferFromDappContract(
                            _third_upline_partner_wallet_address,
                            _level_three_reward
                        );
                        TransactionsLog
                            memory transactionslog = TransactionsLog(
                                _behalf_of,
                                _level_three_reward,
                                "matching_bonus_being_level_three",
                                block.timestamp
                            );
                        transactionLogsByAddress[
                            _third_upline_partner_wallet_address
                        ].push(transactionslog);
                    }
                }
            }
        }
    }

    function referralBonusLogs(
        address _reffered_address,
        address _referrer_partner_address,
        uint256 _amount
    ) internal returns (string memory) {
        TransactionsLog memory transactionslog = TransactionsLog(
            msg.sender,
            _amount,
            "referral_bonus",
            block.timestamp
        );
        transactionLogsByAddress[_referrer_partner_address].push(
            transactionslog
        );
    }

    function partnerBonusesHistory() public returns (TransactionsLog[] memory) {
        require(isValidWalletAddress(), "5");
        return transactionLogsByAddress[msg.sender];
    }

    function allBonusesHistory(
        address _wallet_address
    ) public onlyOwner returns (TransactionsLog[] memory) {
        require(isValidWalletAddress(), "5");
        return transactionLogsByAddress[_wallet_address];
    }
}
