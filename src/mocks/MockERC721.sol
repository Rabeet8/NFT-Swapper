// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {NFTSwapper} from "../NFTSwapper.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Mock ERC721 Token for testing
contract MockERC721 is ERC721 {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => address) private _tokenApprovals;

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        // Additional initialization if needed
    }

    function mint(address to, uint256 tokenId) public {
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _owners[tokenId];
    }

    function approve(address to, uint256 tokenId) public override {
        require(msg.sender == _owners[tokenId], "Not the owner");
        _tokenApprovals[tokenId] = to;
    }

    function getApproved(
        uint256 tokenId
    ) public view override returns (address) {
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public override {
        _operatorApprovals[msg.sender][operator] = approved;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(_owners[tokenId] == from, "Not the owner");
        _owners[tokenId] = to;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        transferFrom(from, to, tokenId);
    }
}
