// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Registry for uploading educational content with metadata and tags.
 * Creators register their content by providing a URI and optional tags.
 */
contract ContentRegistry {
    struct Content {
        address creator;
        string uri;
        string title;
        string[] tags;
        bool active;
    }

    // Access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    mapping(bytes32 => mapping(address => bool)) internal roles;

    // Content storage
    uint256 public nextContentId;
    mapping(uint256 => Content) public contents;

    // Platform pause flag
    bool public paused;

    // Events
    event ContentRegistered(uint256 indexed id, address indexed creator, string uri, string title);
    event ContentStatusChanged(uint256 indexed id, bool active);
    event Paused(bool paused);
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    modifier whenNotPaused() {
        require(!paused, "paused");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "access denied");
        _;
    }

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MODERATOR_ROLE, admin);
    }

    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        paused = false;
        emit Paused(false);
    }

    function registerContent(string calldata uri, string calldata title, string[] calldata tags)
        external
        whenNotPaused
        returns (uint256 id)
    {
        require(bytes(uri).length > 0, "uri required");
        id = ++nextContentId;
        Content storage c = contents[id];
        c.creator = msg.sender;
        c.uri = uri;
        c.title = title;
        c.active = true;

        // copy tags
        for (uint256 i = 0; i < tags.length; i++) {
            c.tags.push(tags[i]);
        }

        emit ContentRegistered(id, msg.sender, uri, title);
    }

    function setActive(uint256 id, bool active) external onlyRole(MODERATOR_ROLE) {
        contents[id].active = active;
        emit ContentStatusChanged(id, active);
    }
}