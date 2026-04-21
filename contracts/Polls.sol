// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract Polls {
    enum PollStatus {
        Upcoming,
        Open,
        Ended,
        Closed
    }

    enum PollResultVisibility {
        Always,
        AfterVote,
        AfterEnd,
        Never
    }

    struct PollSettings {
        bool multiChoice;
        bool noDeadline;
        PollResultVisibility resultVisibility;
    }

    struct Poll {
        address creator;
        uint256 id;
        string title;
        string description;
        uint256 startsAt;
        uint256 endsAt;
        string[] options;
        uint256 pollVotes;
        PollSettings settings;
    }

    struct PollSummary {
        address creator;
        uint256 id;
        string title;
        uint256 pollVotes;
        PollStatus status;
    }

    struct PollDetails {
        address creator;
        string title;
        string description;
        uint256 startsAt;
        uint256 endsAt;
        OptionResult[] options;
        uint256 pollVotes;
        PollSettings settings;
        bool hasVoted;
        uint256[] votedIndices;
    }

    struct OptionResult {
        string text;
        uint256 votes;
    }

    Poll[] public polls;
    mapping(address => uint256[]) public UserPolls;
    mapping(uint256 => mapping(address => bool)) hasVoted;

    mapping(uint256 => uint256) pollVotes;
    mapping(uint256 => mapping(uint256 => uint256)) optionVotes;

    mapping(uint256 => mapping(address => uint256[])) votedIndices;

    event PollCreated(address indexed creator, uint256 indexed pollId);
    event PollClosed(address indexed creator, uint256 indexed pollId);
    event Voted(address indexed voter, uint256 pollId, uint256[] optionIndices);

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

    function createPoll(
        string calldata _title,
        string calldata _desc,
        uint256 _startsAt,
        uint256 _endsAt,
        string[] calldata _options,
        PollSettings calldata _settings
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
        for (uint i = 0; i < _options.length; i++) {
            newPoll.options.push(_options[i]);
        }
        newPoll.pollVotes = 0;
        newPoll.settings = _settings;

        UserPolls[msg.sender].push(pollId);
        emit PollCreated(msg.sender, pollId);
        return pollId;
    }

    function getPollSummaries() public view returns (PollSummary[] memory) {
        uint256[] storage ids = UserPolls[msg.sender];
        uint256 count = ids.length;

        PollSummary[] memory summaries = new PollSummary[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 id = ids[i];
            Poll storage poll = polls[id];

            summaries[i] = PollSummary({
                creator: poll.creator,
                id: id,
                title: poll.title,
                pollVotes: poll.pollVotes,
                status: getStatus(poll)
            });
        }

        return summaries;
    }

    function getPollDetails(
        uint256 _pollId
    ) external view returns (PollDetails memory) {
        Poll storage poll = getPoll(_pollId);

        return
            PollDetails({
                creator: poll.creator,
                title: poll.title,
                description: poll.description,
                startsAt: poll.startsAt,
                endsAt: poll.endsAt,
                options: getOptionsResult(poll),
                pollVotes: poll.pollVotes,
                settings: poll.settings,
                hasVoted: hasVoted[_pollId][msg.sender],
                votedIndices: votedIndices[_pollId][msg.sender]
            });
    }

    function vote(uint256 _pollId, uint256[] calldata _optionIndices) external {
        Poll storage poll = getPoll(_pollId);

        if (getStatus(poll) != PollStatus.Open) revert PollNotOpen();
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
            optionVotes[_pollId][optInx]++;
        }

        poll.pollVotes++;
        hasVoted[_pollId][msg.sender] = true;

        emit Voted(msg.sender, _pollId, _optionIndices);
    }

    function closePoll(uint256 _pollId) external {
        Poll storage poll = getPoll(_pollId);
        if (poll.creator != msg.sender) revert AccessDenied();
        if (getStatus(poll) == PollStatus.Closed) revert PollAlreadyClosed();
        poll.endsAt = 1;

        emit PollClosed(msg.sender, _pollId);
    }

    function getOptionsResult(
        Poll memory _poll
    ) internal view returns (OptionResult[] memory) {
        uint256 len = _poll.options.length;
        OptionResult[] memory results = new OptionResult[](len);

        for (uint256 i = 0; i < len; i++) {
            results[i] = OptionResult({
                text: _poll.options[i],
                votes: optionVotes[_poll.id][i]
            });
        }
        return results;
    }

    function getPoll(uint256 _pollId) internal view returns (Poll storage) {
        if (_pollId >= polls.length) revert PollNotFound(_pollId);
        Poll storage poll = polls[_pollId];
        return poll;
    }

    function getStatus(Poll memory _poll) internal view returns (PollStatus) {
        if (_poll.startsAt > block.timestamp) {
            return PollStatus.Upcoming;
        }

        if (_poll.endsAt == 1) {
            return PollStatus.Closed;
        }

        if (_poll.endsAt > 1 && _poll.endsAt <= block.timestamp) {
            return PollStatus.Ended;
        }

        return PollStatus.Open;
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

    function validateSettings(PollSettings calldata _settings) internal pure {
        if (
            _settings.noDeadline &&
            _settings.resultVisibility == PollResultVisibility.AfterEnd
        ) {
            revert PollResultVisibilitySettingInvalid();
        }
    }
}
