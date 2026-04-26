// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract Polls {
    enum Status {
        Upcoming,
        Open,
        Ended,
        Closed
    }

    enum ResultVisibility {
        Always,
        AfterVote,
        AfterEnd,
        Never
    }

    struct Settings {
        bool multiChoice;
        bool noDeadline;
        ResultVisibility resultVisibility;
    }

    struct Poll {
        uint256 id;
        address creator;
        uint256 startsAt;
        uint256 endsAt;
        uint256 participants;
        uint256 totalVotes;
        uint256 createdAt;
        bool isDeleted;
        Settings settings;
        string title;
        string description;
        string[] options;
    }

    struct Summary {
        address creator;
        uint256 id;
        string title;
        uint256 participants;
        uint256 totalVotes;
        Status status;
        uint256 startsAt;
        uint256 endsAt;
        uint256 createdAt;
    }

    struct Details {
        address creator;
        string title;
        string description;
        uint256 startsAt;
        uint256 endsAt;
        string[] options;
        uint256 participants;
        uint256 totalVotes;
        Status status;
        Settings settings;
        bool hasVoted;
        uint256[] votedIndices;
        uint256 createdAt;
    }

    struct Result {
        string title;
        address creator;
        uint256 participants;
        uint256 totalVotes;
        OptionResult[] optionsResult;
        uint256 createdAt;
    }

    struct OptionResult {
        string text;
        uint256 totalVotes;
    }

    struct UserStats {
        uint256 totalPollsCreated;
        uint256 totalVotesReceived;
    }

    Poll[] polls;
    uint256 totalPollsCreated;
    uint256 totalVotesReceived;
    mapping(address => uint256[]) userPolls;
    mapping(uint256 => mapping(address => bool)) hasVoted;
    mapping(uint256 => uint256) totalVotes;
    mapping(uint256 => mapping(uint256 => uint256)) optionTotalVotes;
    mapping(uint256 => mapping(address => uint256[])) votedIndices;
    mapping(address => uint256) userTotalVotesReceived;
    mapping(address => uint256) userTotalPollsCreated;

    event PollCreated(address indexed creator, uint256 indexed pollId);
    event PollClosed(address indexed creator, uint256 indexed pollId);
    event VoteCast(
        address indexed voter,
        uint256 pollId,
        uint256[] optionIndices
    );
    event PollDeleted(address indexed creator, uint256 indexed pollId);

    error TitleTooShort();
    error TitleTooLarge();
    error DescriptionTooShort();
    error DescriptionTooLarge();
    error PollMustStartInTheFuture();
    error PollMustEndAfterStart();
    error PollMustHaveAtLeastTwoOptions();
    error PollMustHaveAtMostTenOptions();
    error PollResultVisibilitySettingInvalid();
    error OptionTooShort(uint256 index); // Index are the field in options array
    error OptionTooLarge(uint256 index); // Index are the field in options array

    error PollNotFound(uint256 pollId);
    error PollNotOpen();
    error InvalidPollOption();
    error AlreadyVoted();

    error NoOptionSelected();
    error DuplicateOptionSelected();
    error MultiChoiceNotAllowed();

    error AccessDenied();
    error PollAlreadyClosed();
    error PollNotClosed();
    error IncorrectPassword();
    error PollMustHavePassword();

    function createPoll(
        string calldata _title,
        string calldata _desc,
        uint256 _startsAt,
        uint256 _endsAt,
        string[] calldata _options,
        Settings calldata _settings
    ) external returns (uint256) {
        validateTitle(_title);
        validateDesc(_desc);
        validateTimes(_startsAt, _endsAt);
        validateOptions(_options);
        validateSettings(_settings);

        uint256 pollId = polls.length;
        Poll storage newPoll = polls.push();
        newPoll.creator = msg.sender;
        newPoll.id = pollId;
        newPoll.title = _title;
        newPoll.description = _desc;
        newPoll.startsAt = _startsAt;
        newPoll.endsAt = _settings.noDeadline ? 0 : _endsAt;
        newPoll.participants = 0;
        newPoll.totalVotes = 0;
        newPoll.settings = _settings;
        newPoll.createdAt = block.timestamp;
        newPoll.isDeleted = false;
        for (uint i = 0; i < _options.length; i++) {
            newPoll.options.push(_options[i]);
        }

        // Store this poll for creator
        userPolls[msg.sender].push(pollId);

        // Increase 1 for total polls of user
        userTotalPollsCreated[msg.sender]++;

        // For count total polls of system
        totalPollsCreated++;

        emit PollCreated(msg.sender, pollId);
        return pollId;
    }

    function getPollSummaries() public view returns (Summary[] memory) {
        uint256[] storage ids = userPolls[msg.sender];
        uint256 totalCount = ids.length;

        uint256 validCount = 0;
        for (uint256 i = 0; i < totalCount; i++) {
            if (!polls[ids[i]].isDeleted) {
                validCount++;
            }
        }

        Summary[] memory summaries = new Summary[](validCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalCount; i++) {
            uint256 id = ids[i];
            if (polls[id].isDeleted) continue;

            Poll storage poll = polls[id];
            summaries[currentIndex] = Summary({
                creator: poll.creator,
                id: id,
                title: poll.title,
                participants: poll.totalVotes,
                totalVotes: poll.totalVotes,
                status: getStatus(poll),
                startsAt: poll.startsAt,
                endsAt: poll.endsAt,
                createdAt: poll.createdAt
            });
            currentIndex++;
        }

        return summaries;
    }

    function getPollDetails(
        uint256 _pollId
    ) external view returns (Details memory) {
        Poll storage poll = getPoll(_pollId);

        return
            Details({
                creator: poll.creator,
                title: poll.title,
                description: poll.description,
                startsAt: poll.startsAt,
                endsAt: poll.endsAt,
                options: poll.options,
                participants: poll.participants,
                totalVotes: poll.totalVotes,
                settings: poll.settings,
                hasVoted: hasVoted[_pollId][msg.sender],
                votedIndices: votedIndices[_pollId][msg.sender],
                createdAt: poll.createdAt,
                status: getStatus(poll)
            });
    }

    function getPollResults(
        uint256 _pollId,
        address _voter
    ) external view returns (Result memory) {
        Poll storage poll = getPoll(_pollId);

        if (!shouldShowResults(poll, _voter)) revert AccessDenied();

        OptionResult[] memory optionsResult = getOptionsResult(poll);
        return
            Result({
                title: poll.title,
                creator: poll.creator,
                optionsResult: optionsResult,
                participants: poll.participants,
                totalVotes: poll.totalVotes,
                createdAt: poll.createdAt
            });
    }

    function getUserStats(
        address _user
    ) external view returns (UserStats memory) {
        UserStats memory stats;

        stats.totalPollsCreated = userTotalPollsCreated[_user];
        stats.totalVotesReceived = userTotalVotesReceived[_user];

        return stats;
    }

    function castVote(
        uint256 _pollId,
        uint256[] calldata _optionIndices
    ) external {
        Poll storage poll = getPoll(_pollId);

        if (getStatus(poll) != Status.Open) revert PollNotOpen();
        if (hasVoted[_pollId][msg.sender]) revert AlreadyVoted();

        uint256 numChoices = _optionIndices.length;
        if (numChoices == 0) revert NoOptionSelected();

        if (!poll.settings.multiChoice && numChoices > 1) {
            revert MultiChoiceNotAllowed();
        }

        for (uint256 i = 0; i < numChoices; i++) {
            uint256 optInx = _optionIndices[i];
            if (optInx >= poll.options.length) revert InvalidPollOption();
            for (uint256 j = 0; j < i; j++) {
                if (_optionIndices[i] == _optionIndices[j]) {
                    revert DuplicateOptionSelected();
                }
            }
            // With each choisen option is a vote
            poll.totalVotes++;

            // Increase 1 vote on this option
            optionTotalVotes[_pollId][optInx]++;

            userTotalVotesReceived[msg.sender]++;
        }

        // Mark this user as has voted
        hasVoted[_pollId][msg.sender] = true;

        // The option the user cast vote
        votedIndices[_pollId][msg.sender] = _optionIndices;

        // Total votes of all polls
        totalVotesReceived++;

        // The participant of this poll
        poll.participants++;

        emit VoteCast(msg.sender, _pollId, _optionIndices);
    }

    function closePoll(uint256 _pollId) external {
        Poll storage poll = getPoll(_pollId);
        if (poll.creator != msg.sender) revert AccessDenied();
        if (getStatus(poll) == Status.Closed) revert PollAlreadyClosed();

        // 1 is closed, 0 is no deadline
        poll.endsAt = 1;

        emit PollClosed(msg.sender, _pollId);
    }

    function deletePoll(uint256 _pollId) external {
        Poll storage poll = getPoll(_pollId);
        if (poll.creator != msg.sender) revert AccessDenied();

        // Mark as deleted
        poll.isDeleted = true;

        emit PollDeleted(poll.creator, _pollId);
    }

    function shouldShowResults(
        Poll memory _poll,
        address _voter
    ) internal view returns (bool) {
        if (_poll.settings.resultVisibility == ResultVisibility.Never) {
            return false;
        }
        if (
            _poll.settings.resultVisibility == ResultVisibility.AfterVote &&
            !hasVoted[_poll.id][_voter]
        ) {
            return false;
        }
        if (
            _poll.settings.resultVisibility == ResultVisibility.AfterEnd &&
            getStatus(_poll) != Status.Ended &&
            getStatus(_poll) != Status.Closed
        ) {
            return false;
        }
        return true;
    }

    function getOptionsResult(
        Poll memory _poll
    ) internal view returns (OptionResult[] memory) {
        uint256 len = _poll.options.length;
        OptionResult[] memory results = new OptionResult[](len);

        for (uint256 i = 0; i < len; i++) {
            results[i] = OptionResult({
                text: _poll.options[i],
                totalVotes: optionTotalVotes[_poll.id][i]
            });
        }
        return results;
    }

    function getPoll(uint256 _pollId) internal view returns (Poll storage) {
        require(_pollId <= polls.length, "PollNotFound");
        Poll storage poll = polls[_pollId];
        if (poll.isDeleted) revert PollNotFound(_pollId);
        return poll;
    }

    function getStatus(Poll memory _poll) internal view returns (Status) {
        if (_poll.startsAt > block.timestamp) {
            return Status.Upcoming;
        }

        if (_poll.endsAt == 1) {
            return Status.Closed;
        }

        if (_poll.endsAt > 1 && _poll.endsAt <= block.timestamp) {
            return Status.Ended;
        }

        return Status.Open;
    }

    function validateTitle(string calldata _title) internal pure {
        uint256 length = bytes(_title).length;
        if (length < 3) revert TitleTooShort();
        if (length > 100) revert TitleTooLarge();
    }

    function validateDesc(string calldata _desc) internal pure {
        uint256 length = bytes(_desc).length;
        if (length > 0 && length < 10) revert DescriptionTooShort();
        if (length > 1000) revert DescriptionTooLarge();
    }

    function validateTimes(uint256 _startsAt, uint256 _endsAt) internal view {
        if (_startsAt < block.timestamp) revert PollMustStartInTheFuture();
        if (_endsAt <= _startsAt) revert PollMustEndAfterStart();
    }

    function validateOptions(string[] calldata _options) internal pure {
        uint256 optionsLength = _options.length;
        if (optionsLength < 2) revert PollMustHaveAtLeastTwoOptions();
        if (optionsLength > 10) revert PollMustHaveAtMostTenOptions();

        for (uint256 i = 0; i < optionsLength; ++i) {
            uint256 optionLength = bytes(_options[i]).length;
            if (optionLength < 1) revert OptionTooShort(i);
            if (optionLength > 100) revert OptionTooLarge(i);
        }
    }

    function validateSettings(Settings calldata _settings) internal pure {
        if (
            _settings.noDeadline &&
            _settings.resultVisibility == ResultVisibility.AfterEnd
        ) {
            revert PollResultVisibilitySettingInvalid();
        }
    }
}
