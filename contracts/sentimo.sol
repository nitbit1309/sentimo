//SPDX-License-Identifier: GPL3

pragma solidity ^0.8.0;

contract Sentimo {
    //Structure to store participant data
    struct ParticipantResponse {
        bool isRewardWithdrawn;
        uint8 optionSelected;
        uint8 quizAnsPerct;
        bytes32 secretHash;
    }

    //Structure to hold a single poll game
    struct Poll {
        //Below variables are initialized at the time of poll creation
        string pollUrl; //A URL which hosts poll content in JSON
        uint8 pollOptionsCount; //Options available in poll
        uint8 quizGameOption;
        address creator; // Address of the poll creator
        uint32 voteTimeout; // Timeout in seconds before voting time expires. The timer will get started after poll creation
        uint32 revealTimeout; // Timeout in seconds before reveal time expires. The timer will get started after voting time expires.
        bool isCreatorRewardsWithdrawn; // Whether poll creator has withdrawn his rewards.
        uint256 creationTime; // Time at which this poll gets created
        uint256 fee; // A fee for players to participate in the poll in wei
        uint256 baseReward; // A Base reward (minimum reward)that will be distributed among the players if they win
        uint256 quizGameOptionSelectedCount; //How many participants have selected quizGameOption.
        uint256 pollResponsesCount; //Count of total responses received
        // ParticipantResponse[] participantResponseList; // A list of participants infomation
        mapping(address => ParticipantResponse) participantResponsesMap; // A map to track which addresses have participated in the poll
    }

    error InvalidPollId();
    error ErrorVotingTimeExpired();
    error ErrorRevealTimeExpired();
    error ErrorRevealTimeNotStarted();
    error ErrorRevealTimeNotExpired();

    error ErrorInvalidSecretHash(
        uint pollId,
        address sender,
        bytes32 calculatedHash,
        bytes32 correctHash
    );

    //Events
    event PollCreated(
        uint256 indexed pollId,
        address indexed creator,
        uint256 baseReward
    );
    event RewardTransferred(
        address indexed benificieary,
        uint value,
        bool isPollCreator
    );

    address internal owner;
    Poll[] public polls;
    uint contractFeePerct = 5;

    constructor() {
        owner = msg.sender;
    }

    //Receive payable function for default value transfer
    receive() external payable {}

    /* Pure methods*/
    function getBidHash(
        uint8 _option,
        uint32 _quizAns,
        string memory _secret
    ) public pure returns (bytes32 _hash) {
        return keccak256(abi.encodePacked(_option, _quizAns, _secret));
    }

    /* View Methods */
    //Function to return count of all the existing polls
    function getAvilablePollsCount() external view returns (uint count) {
        count = polls.length;
    }

    function _getPollCreatorClaim(uint _pollId)
        internal
        view
        returns (uint _creatorsClaim)
    {
        Poll storage poll = polls[_pollId];

        uint baseReward = poll.baseReward;
        uint participantPool = poll.pollResponsesCount * poll.fee;
        uint creatorReward = 0;

        if (baseReward == participantPool) return 0;
        else if (baseReward < participantPool) {
            creatorReward =
                baseReward +
                ((participantPool - baseReward) * 20) /
                100;
            if (creatorReward > baseReward * 2)
                //2X Cap on creator's earning
                creatorReward = baseReward * 2;
        } else {
            creatorReward = poll.baseReward - participantPool;
        }
        return creatorReward;
    }

    function getPollCreatorReward(uint _pollId)
        public
        view
        onlyValidPoll(_pollId)
        onlyAfterRevealTimeout(_pollId)
        returns (uint _creatorsClaim)
    {
        uint claimAmount = _getPollCreatorClaim(_pollId);
        if (claimAmount > 0) {
            //Deduct contract fee
            return claimAmount - (claimAmount * contractFeePerct) / 100;
        } else return 0;
    }

    function getPlayersReward(uint _pollId, address addr)
        public
        view
        onlyValidPoll(_pollId)
        onlyAfterRevealTimeout(_pollId)
        returns (uint _playerReward)
    {
        Poll storage poll = polls[_pollId];
        ParticipantResponse storage pr = poll.participantResponsesMap[addr];

        require(
            uint(pr.optionSelected) != 0,
            "Player has not participate /reveal vote"
        );

        if (
            pr.quizAnsPerct !=
            (poll.quizGameOptionSelectedCount * 100) / poll.pollResponsesCount
        ) return 0;

        uint totalRewardForPlayers = poll.baseReward +
            poll.pollResponsesCount *
            poll.fee -
            _getPollCreatorClaim(_pollId);

        uint totalRewardPerPlayers = totalRewardForPlayers /
            poll.quizGameOptionSelectedCount;

        return
            totalRewardPerPlayers -
            ((totalRewardPerPlayers * contractFeePerct) / 100);
    }

    /* Modifiers */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    modifier onlyAfterRevealTimeout(uint pollId) {
        Poll storage poll = polls[pollId];

        uint revealTimeout = poll.creationTime +
            poll.voteTimeout +
            poll.revealTimeout;
        if (revealTimeout > block.timestamp) revert ErrorRevealTimeNotExpired();
        _;
    }

    modifier onlyValidPoll(uint pollId) {
        require(pollId < polls.length, "Not a valid pollId");
        _;
    }

    //Transaction Functions
    function createPoll(
        string calldata _contentUrl, //URL where poll content is hosted
        uint32 _votingTimeout, //Voting allowed time in second after poll creation
        uint32 _revealTimeout, //Vote reveal time in second after voting closes
        uint _fee, //Minimum fee for the participants
        uint8 _quizGameOption, //Option for which poll game percentage will get calculated
        uint8 _noOfOptions //Total no of options vailable in poll
    ) external payable returns (uint pollId) {
        //Game quiz must be one of the option available.
        require(
            _noOfOptions <= 4 && _noOfOptions > 0,
            "Total no of options can only be in between 1..4"
        );
        require(
            _noOfOptions >= _quizGameOption,
            "Invalid game quiz option number"
        );

        Poll storage poll = polls.push();
        poll.creator = msg.sender;
        poll.fee = _fee;
        poll.voteTimeout = _votingTimeout;
        poll.revealTimeout = _revealTimeout;
        poll.pollUrl = _contentUrl;
        poll.quizGameOption = _quizGameOption;
        poll.creationTime = block.timestamp;
        poll.pollOptionsCount = _noOfOptions;
        poll.baseReward = msg.value;
        return polls.length - 1;
    }

    function castHiddenPoll(uint _pollId, bytes32 _secretHash)
        external
        payable
        onlyValidPoll(_pollId)
    {
        Poll storage poll = polls[_pollId];
        if (poll.creationTime + poll.voteTimeout < block.timestamp)
            revert ErrorVotingTimeExpired();

        require(
            uint256(poll.participantResponsesMap[msg.sender].secretHash) == 0,
            "Already voted"
        );
        require(poll.fee == msg.value, "Invalid poll fee");

        poll.pollResponsesCount += 1;
        poll.participantResponsesMap[msg.sender].secretHash = _secretHash;
    }

    function revealVote(
        uint _pollId,
        uint8 _optionSelected,
        uint8 _quizAnsPerct,
        string memory _secret
    ) external payable onlyValidPoll(_pollId) {
        Poll storage poll = polls[_pollId];
        ParticipantResponse storage pr = poll.participantResponsesMap[
            msg.sender
        ];

        //Validate User Input
        require(pr.secretHash.length != 0, "User has not voted");
        require(_quizAnsPerct <= 100, "quiz answer percentage is not valid");
        require(
            _optionSelected > 0 && _optionSelected <= poll.pollOptionsCount,
            "Invalid option selected"
        );

        //Validate time for this action
        uint votingTimeout = poll.creationTime + poll.voteTimeout;
        uint revealTimeout = votingTimeout + poll.revealTimeout;
        if (votingTimeout >= block.timestamp)
            revert ErrorRevealTimeNotStarted();
        else if (revealTimeout < block.timestamp)
            revert ErrorRevealTimeExpired();

        //validate hash
        bytes32 calHash = getBidHash(_optionSelected, _quizAnsPerct, _secret);
        if (calHash != pr.secretHash)
            revert ErrorInvalidSecretHash(
                _pollId,
                msg.sender,
                calHash,
                pr.secretHash
            );

        pr.optionSelected = _optionSelected;
        pr.quizAnsPerct = _quizAnsPerct;
        if (_optionSelected == poll.quizGameOption)
            poll.quizGameOptionSelectedCount++;
    }

    function claimRewards(uint _pollId)
        external
        onlyValidPoll(_pollId)
        onlyAfterRevealTimeout(_pollId)
    {
        Poll storage poll = polls[_pollId];
        ParticipantResponse storage pr = poll.participantResponsesMap[
            msg.sender
        ];
        uint reward = 0;

        if (msg.sender == poll.creator) {
            require(
                !poll.isCreatorRewardsWithdrawn,
                "Rewards already withdrawn"
            );
            reward = getPollCreatorReward(_pollId);
        }
        require(!pr.isRewardWithdrawn, "Rewards already withdrawn");
        reward += getPlayersReward(_pollId, msg.sender);

        if (reward > 0) {
            poll.isCreatorRewardsWithdrawn = true;
            pr.isRewardWithdrawn = true;
            payable(msg.sender).transfer(reward);
            emit RewardTransferred(
                msg.sender,
                reward,
                msg.sender == poll.creator
            );
        } else revert("Reward amount is 0");
    }
}
