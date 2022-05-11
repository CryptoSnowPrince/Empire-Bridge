pragma solidity ^0.8.11;

interface IEmpireToken {
  function mint(address account, uint tAmount) external;
  function burn(address account, uint tAmount) external;
}