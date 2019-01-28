/**
 * This smart contract code is Copyright 2018 TokenMarket Ltd. For more information see https://tokenmarket.net
 * Licensed under the Apache License, version 2.0: https://github.com/TokenMarketNet/ico/blob/master/LICENSE.txt
 * NatSpec is used intentionally to cover also other than public functions
 * Solidity 0.4.18 is intentionally used: it's stable, and our framework is
 * based on that.
 */

pragma solidity ^0.4.18;

import "../CrowdsaleToken.sol";
import "../Recoverable.sol";
import "./CheckpointToken.sol";
import "./ERC865.sol";
import "zeppelin/contracts/math/SafeMath.sol";
import "zeppelin/contracts/ownership/Whitelist.sol";
import "zeppelin/contracts/ownership/rbac/RBAC.sol";

/**
 * @dev Interface for general announcements about the security.
 *
 * Announcements can be for instance for dividend sharing, voting, or
 * just for general announcements.
 */
interface Announcement {
  function announcementName() public view returns (bytes32);
  function announcementURI() public view returns (bytes32);
  function announcementType() public view returns (uint256);
  function announcementHash() public view returns (uint256);
}

/**
 * @author TokenMarket /  Ville Sundell <ville at tokenmarket.net>
 */
contract SecurityToken is CheckpointToken, RBAC, Recoverable, ERC865 {
  using SafeMath for uint256; // We use only uint256 for safety reasons (no boxing)

  string public version = 'TM-01 0.1';

  string constant ROLE_ANNOUNCE = "announce()";
  string constant ROLE_FORCE = "forceTransfer()";
  string constant ROLE_ISSUE = "issueTokens()";
  string constant ROLE_BURN = "burnTokens()";
  string constant ROLE_INFO = "setTokenInformation()";
  string constant ROLE_SETVERIFIER = "setTransactionVerifier()";

  string public url;

  /** SecurityToken specific events **/
  event Issued(address indexed to, uint256 value);
  event Burned(address indexed burner, uint256 value);
  event Forced(address indexed from, address indexed to, uint256 value);
  event Announced(address indexed announcement, uint256 indexed announcementType, bytes32 indexed announcementName, bytes32 announcementURI, uint256 announcementHash);
  event UpdatedTokenInformation(string newName, string newSymbol, string newUrl);
  event UpdatedTransactionVerifier(address newVerifier);

  address[] public announcements;
  mapping(address => uint256) public announcementsByAddress;

  /**
   * @dev Contructor to create SecurityToken, and subsequent CheckpointToken.
   *
   * CheckpointToken will be created with hardcoded 18 decimals.
   *
   * @param _name Initial name of the token
   * @param _symbol Initial symbol of the token
   */
  function SecurityToken(string _name, string _symbol, string _url) CheckpointToken(_name, _symbol, 18) public {
    url = _url;

    addRole(msg.sender, ROLE_ANNOUNCE);
    addRole(msg.sender, ROLE_FORCE);
    addRole(msg.sender, ROLE_ISSUE);
    addRole(msg.sender, ROLE_BURN);
    addRole(msg.sender, ROLE_INFO);
    addRole(msg.sender, ROLE_SETVERIFIER);
  }

  /**
   * @dev Function to announce Announcements.
   *
   * Announcements can be for instance for dividend sharing, voting, or
   * just for general announcements.
   *
   * Instead of storing the announcement details, we just broadcast them as an
   * event, and store only the address.
   *
   * @param announcement Address of the Announcement
   */
  function announce(Announcement announcement) external onlyRole(ROLE_ANNOUNCE) {
    announcements.push(announcement);
    announcementsByAddress[address(announcement)] = announcements.length;
    Announced(address(announcement), announcement.announcementType(), announcement.announcementName(), announcement.announcementURI(), announcement.announcementHash());
  }

  /**
   * @dev Function to forcefully transfer tokens from A to B by board decission
   *
   * This must be implemented carefully, since this is a very critical part
   * to ensure investor safety.
   *
   * This is intended to be called by the BAC (The Board), hence the whitelisting.
   *
   * @param from Address of the account to confisticate the tokens from
   * @param to Address to deposit the confisticated token to
   * @param value amount of tokens to be confisticated
   */
  function forceTransfer(address from, address to, uint256 value) external onlyRole(ROLE_FORCE) {
    transferInternal(from, to, value);

    Forced(from, to, value);
  }

  /**
   * @dev Issue new tokens to the board by a board decission
   *
   * Issue new tokens. This is intended to be called by the BAC (The Board),
   * hence the whitelisting.
   *
   * @param value Token amount to issue
   */
  function issueTokens(uint256 value) external onlyRole(ROLE_ISSUE) {
    address issuer = msg.sender;
    uint256 blackHoleBalance = balanceOf(address(0));
    uint256 totalSupplyNow = totalSupply();

    setCheckpoint(tokenBalances[address(0)], blackHoleBalance.add(value));
    transferInternal(address(0), issuer, value);
    setCheckpoint(tokensTotal, totalSupplyNow.add(value));

    Issued(issuer, value);
  }

  /**
   * @dev Burn tokens from contract's own balance by a board decission
   *
   * Burn tokens from contract's own balance to prevent accidental burnings.
   * This is intended to be called by the BAC (The Board), hence the whitelisting.
   *
   * @param value Token amount to burn from this contract's balance
   */
  function burnTokens(uint256 value) external onlyRole(ROLE_BURN) {
    address burner = address(this);
    uint256 burnerBalance = balanceOf(burner);
    uint256 totalSupplyNow = totalSupply();

    transferInternal(burner, address(0), value);
    setCheckpoint(tokenBalances[address(0)], burnerBalance.sub(value));
    setCheckpoint(tokensTotal, totalSupplyNow.sub(value));

    Burned(burner, value);
  }

  /**
   * @dev Whitelisted users (The Board, BAC) can update token information here.
   *
   * It is often useful to conceal the actual token association, until
   * the token operations, like central issuance or reissuance have been completed.
   *
   * This function allows the token owner to rename the token after the operations
   * have been completed and then point the audience to use the token contract.
   *
   * @param _name New name of the token
   * @param _symbol New symbol of the token
   * @param _url New URL of the token
   */
  function setTokenInformation(string _name, string _symbol, string _url) external onlyRole(ROLE_INFO) {
    name = _name;
    symbol = _symbol;
    url = _url;

    UpdatedTokenInformation(name, symbol, url);
  }

  /**
   * @dev Set transaction verifier
   *
   * This sets a SecurityTransferAgent to be used as a transaction verifier for
   * each transfer. This is implemented for possible regulatory requirements.
   *
   * @param newVerifier Address of the SecurityTransferAgent used as verifier
   */
  function setTransactionVerifier(SecurityTransferAgent newVerifier) external onlyRole(ROLE_SETVERIFIER) {
    transferVerifier = newVerifier;

    UpdatedTransactionVerifier(newVerifier);
  }
}
