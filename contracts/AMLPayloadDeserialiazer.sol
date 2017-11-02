/**
 * This smart contract code is Copyright 2017 TokenMarket Ltd. For more information see https://tokenmarket.net
 *
 * Licensed under the Apache License, version 2.0: https://github.com/TokenMarketNet/ico/blob/master/LICENSE.txt
 */


import "./BytesDeserializer.sol";

/**
 * A mix-in contract to decode different AML payloads.
 *
 * @notice This should be a library, but for the complexity and toolchain fragility risks involving of linking library inside library, we put this as a mix-in.
 */
contract AMLPayloadDeserialiazer {

  using BytesDeserializer for bytes;

  // The bytes payload set on the server side
  // total 56 bytes

  struct AMLPayload {

    /** Customer whitelisted address where the deposit can come from */
    address whitelistedAddress; // 20 bytes

    /** Customer id, UUID v4 */
    uint128 customerId; // 16 bytes

    /**
     * Min amount this customer needs to invest in ETH. Set zero if no minimum. Expressed as parts of 10000. 1 ETH = 10000.
     * @notice Decided to use 32-bit words to make the copy-pasted Data field for the ICO transaction less lenghty.
     */
    uint32 minETH; // 4 bytes

    /** Max amount this customer can to invest in ETH. Set zero if no maximum. Expressed as parts of 10000. 1 ETH = 10000. */
    uint32 maxETH; // 4 bytes
  }

  /**
   * Deconstruct server-side byte data to structured data.
   */
  function deserializeAMLPayload(bytes dataframe) private constant returns(AMLPayload decodedPayload) {
    AMLPayload payload;
    payload.whitelistedAddress = dataframe.sliceAddress(0);
    payload.customerId = uint128(dataframe.slice16(20));
    payload.minETH = uint32(dataframe.slice4(36));
    payload.maxETH = uint32(dataframe.slice4(40));
    return payload;
  }

  /**
   * Helper function to allow us to return the decoded payload to an external caller for testing.
   */
  function getAMLPayload(bytes dataframe) public constant returns(address whitelistedAddress, uint128 customerId, uint32 minEth, uint32 maxEth) {
    AMLPayload memory payload = deserializeAMLPayload(dataframe);
    return (payload.whitelistedAddress, payload.customerId, payload.minETH, payload.maxETH);
  }

  /**
   * @param customerMin (optional, can be zero) How much this customer needs to invest.
   *                    A signed server side set parameter by the current AML policy.
   * @param customerMax (optional, can be zero) How much this customer can invest.
   *                    A signed server side set parameter by the current AML policy.
   */
  function checkAMLLimits(uint128 customerId, uint weiAmount, uint customerMin, uint customerMax) private {

    /*
    investedCustomerAmountOf[customerId] = investedCustomerAmountOf[customerId].plus(weiAmount);

    // Check AML boundaries (if given)
    if(customerMin != 0) {
      require(investedCustomerAmountOf[customerId] >= customerMin);
    }

    if(customerMax != 0) {
      require(investedCustomerAmountOf[customerId] <= customerMax);
    }*/
  }

}
