/*
 * SPDX-License-Identifier:    MIT
 */

pragma solidity 0.4.24;

import "./TokenCache.sol";
import "./BaseTemplate.sol";

import "./lib/os/ERC20.sol";


contract SnapshotTemplate is BaseTemplate, TokenCache {
    string constant private ERROR_MISSING_CACHE = "TEMPLATE_MISSING_TOKEN_CACHE";
    string constant private ERROR_EMPTY_HOLDERS = "EMPTY_HOLDERS";
    string constant private ERROR_BAD_HOLDERS_STAKES_LEN = "BAD_HOLDERS_STAKES_LEN";
    string constant private ERROR_BAD_VOTE_SETTINGS = "BAD_VOTE_SETTINGS";
    string constant private ERROR_BAD_COLLATERAL_REQUIREMENT_SETTINGS = "BAD_COL_REQ_SETTINGS";

    bool constant private SET_APP_FEES_CASHIER = false;
    bool constant private TOKEN_TRANSFERABLE = true;
    uint8 constant private TOKEN_DECIMALS = uint8(18);
    uint256 constant private TOKEN_MAX_PER_ACCOUNT = uint256(0);

    struct Cache {
        address dao;
        address tokenManager;
        address agreement;
    }

    mapping (address => Cache) internal cache;

    constructor(DAOFactory _daoFactory, ENS _ens, MiniMeTokenFactory _miniMeFactory)
        BaseTemplate(_daoFactory, _ens, _miniMeFactory)
        public
    {}

    function createDAO(string _name, string _symbol, address[] _holders, uint256[] _stakes) external {
        (Kernel dao, ACL acl) = _createDAO();
        MiniMeToken token = _createToken(_name, _symbol, TOKEN_DECIMALS);

        TokenManager tokenManager = _installTokenManagerApp(dao, token, TOKEN_TRANSFERABLE, TOKEN_MAX_PER_ACCOUNT);
        _mintTokens(acl, tokenManager, _holders, _stakes);
        _storeCache(dao, tokenManager);
    }

    function installAgreement(string _title, bytes _content, address _arbitrator, address _stakingFactory) external {
        Kernel dao = _loadCache();
        Agreement agreement = _installAgreementApp(dao, _arbitrator, SET_APP_FEES_CASHIER, _title, _content, _stakingFactory);
        _storeCache(agreement);
    }

    function installApps(
        address _submitter,
        address _challenger,
        uint64 _executionDelay,
        uint256[4] _collateralRequirements
    )
        external
    {
        (Kernel dao, TokenManager tokenManager, Agreement agreement) = _popCache();
        DisputableDelay delay = _setupApps(dao, agreement, tokenManager, _executionDelay, _collateralRequirements);

        ACL acl = ACL(dao.acl());
        acl.createPermission(_submitter, delay, delay.DELAY_EXECUTION_ROLE(), tokenManager);
        acl.createPermission(_challenger, delay, delay.CHALLENGE_ROLE(), tokenManager);

        _transferRootPermissionsFromTemplateAndFinalizeDAO(dao, delay, tokenManager);
    }

    function _setupApps(
        Kernel _dao,
        Agreement _agreement,
        TokenManager _tokenManager,
        uint64 _executionDelay,
        uint256[4] _collateralRequirements
    )
        internal
        returns (DisputableDelay)
    {
        ACL acl = ACL(_dao.acl());
        Agent agent = _installAgentApp(_dao);
        DisputableDelay delay = _installDisputableDelayApp(_dao, _executionDelay);

        //_setupPermissions(acl, agent, _agreement, delay, _tokenManager);
        //_activateDisputableDelay(acl, _agreement, delay, _collateralRequirements);

        return (delay);
    }

    function _setupPermissions(
        ACL _acl,
        Agent _agent,
        Agreement _agreement,
        DisputableDelay _delay,
        TokenManager _tokenManager
    )
        internal
    {
        _createAgentPermissions(_acl, _agent, _delay, _tokenManager);
        _createVaultPermissions(_acl, Vault(_agent), _delay, _tokenManager);
        _createAgreementPermissions(_acl, _agreement, _delay, _tokenManager);
        _createEvmScriptsRegistryPermissions(_acl, _delay, _delay);
        _createDisputableDelayPermissions(_acl, _delay, _delay, _tokenManager);
        _createTokenManagerPermissions(_acl, _tokenManager, _tokenManager, _tokenManager);
    }

    function _activateDisputableDelay(
        ACL _acl,
        Agreement _agreement,
        DisputableDelay _delay,
        uint256[4] _collateralRequirements
    )
        internal
    {
        ERC20 collateralToken = ERC20(_collateralRequirements[0]);
        uint64 challengeDuration = uint64(_collateralRequirements[1]);
        uint256 actionCollateral = _collateralRequirements[2];
        uint256 challengeCollateral = _collateralRequirements[3];

        _acl.createPermission(_agreement, _delay, _delay.SET_AGREEMENT_ROLE(), _delay);
        _agreement.activate(_delay, collateralToken, challengeDuration, actionCollateral, challengeCollateral);
        _transferPermissionFromTemplate(_acl, _agreement, _delay, _agreement.MANAGE_DISPUTABLE_ROLE(), _delay);
    }

    function _storeCache(Kernel _dao, TokenManager _tokenManager) internal {
        Cache storage c = cache[msg.sender];

        c.dao = address(_dao);
        c.tokenManager = address(_tokenManager);
    }

    function _storeCache(Agreement _agreement) internal {
        Cache storage c = cache[msg.sender];
        c.agreement = address(_agreement);
    }

    function _loadCache() internal returns (Kernel) {
        Cache storage c = cache[msg.sender];
        require(c.dao != address(0), ERROR_MISSING_CACHE);
        return Kernel(c.dao);
    }

    function _popCache() internal returns (Kernel dao, TokenManager tokenManager, Agreement agreement) {
        Cache storage c = cache[msg.sender];
        require(c.dao != address(0) && c.tokenManager != address(0), ERROR_MISSING_CACHE);

        dao = Kernel(c.dao);
        tokenManager = TokenManager(c.tokenManager);
        agreement = Agreement(c.agreement);

        delete c.dao;
        delete c.tokenManager;
        delete c.agreement;
    }
}
