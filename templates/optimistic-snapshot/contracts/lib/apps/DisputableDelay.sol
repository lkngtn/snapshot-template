/*
 * SPDX-License-Identifier:    MIT
 */

pragma solidity 0.4.24;

import "../minime/MiniMeToken.sol";


interface DisputableDelay {
    function SET_AGREEMENT_ROLE() external pure returns (bytes32);
    function CHALLENGE_ROLE() external pure returns (bytes32);
    function DELAY_EXECUTION_ROLE() external pure returns (bytes32);
    function SET_DELAY_ROLE() external pure returns (bytes32);

    function initialize(
        uint64 _executionDelay
    ) external;
}
