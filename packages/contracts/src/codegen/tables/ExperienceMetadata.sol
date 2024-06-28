// SPDX-License-Identifier: MIT
pragma solidity >=0.8.24;

/* Autogenerated file. Do not edit manually. */

// Import store internals
import { IStore } from "@latticexyz/store/src/IStore.sol";
import { StoreSwitch } from "@latticexyz/store/src/StoreSwitch.sol";
import { StoreCore } from "@latticexyz/store/src/StoreCore.sol";
import { Bytes } from "@latticexyz/store/src/Bytes.sol";
import { Memory } from "@latticexyz/store/src/Memory.sol";
import { SliceLib } from "@latticexyz/store/src/Slice.sol";
import { EncodeArray } from "@latticexyz/store/src/tightcoder/EncodeArray.sol";
import { FieldLayout } from "@latticexyz/store/src/FieldLayout.sol";
import { Schema } from "@latticexyz/store/src/Schema.sol";
import { EncodedLengths, EncodedLengthsLib } from "@latticexyz/store/src/EncodedLengths.sol";
import { ResourceId } from "@latticexyz/store/src/ResourceId.sol";

struct ExperienceMetadataData {
  address contractAddress;
  bool shouldDelegate;
  bytes32[] hookSystemIds;
  string name;
  string description;
}

library ExperienceMetadata {
  // Hex below is the result of `WorldResourceIdLib.encode({ namespace: "experience", name: "ExperienceMetada", typeId: RESOURCE_TABLE });`
  ResourceId constant _tableId = ResourceId.wrap(0x7462657870657269656e636500000000457870657269656e63654d6574616461);

  FieldLayout constant _fieldLayout =
    FieldLayout.wrap(0x0015020314010000000000000000000000000000000000000000000000000000);

  // Hex-encoded key schema of ()
  Schema constant _keySchema = Schema.wrap(0x0000000000000000000000000000000000000000000000000000000000000000);
  // Hex-encoded value schema of (address, bool, bytes32[], string, string)
  Schema constant _valueSchema = Schema.wrap(0x001502036160c1c5c50000000000000000000000000000000000000000000000);

  /**
   * @notice Get the table's key field names.
   * @return keyNames An array of strings with the names of key fields.
   */
  function getKeyNames() internal pure returns (string[] memory keyNames) {
    keyNames = new string[](0);
  }

  /**
   * @notice Get the table's value field names.
   * @return fieldNames An array of strings with the names of value fields.
   */
  function getFieldNames() internal pure returns (string[] memory fieldNames) {
    fieldNames = new string[](5);
    fieldNames[0] = "contractAddress";
    fieldNames[1] = "shouldDelegate";
    fieldNames[2] = "hookSystemIds";
    fieldNames[3] = "name";
    fieldNames[4] = "description";
  }

  /**
   * @notice Register the table with its config.
   */
  function register() internal {
    StoreSwitch.registerTable(_tableId, _fieldLayout, _keySchema, _valueSchema, getKeyNames(), getFieldNames());
  }

  /**
   * @notice Register the table with its config.
   */
  function _register() internal {
    StoreCore.registerTable(_tableId, _fieldLayout, _keySchema, _valueSchema, getKeyNames(), getFieldNames());
  }

  /**
   * @notice Get contractAddress.
   */
  function getContractAddress() internal view returns (address contractAddress) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (address(bytes20(_blob)));
  }

  /**
   * @notice Get contractAddress.
   */
  function _getContractAddress() internal view returns (address contractAddress) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 0, _fieldLayout);
    return (address(bytes20(_blob)));
  }

  /**
   * @notice Set contractAddress.
   */
  function setContractAddress(address contractAddress) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((contractAddress)), _fieldLayout);
  }

  /**
   * @notice Set contractAddress.
   */
  function _setContractAddress(address contractAddress) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setStaticField(_tableId, _keyTuple, 0, abi.encodePacked((contractAddress)), _fieldLayout);
  }

  /**
   * @notice Get shouldDelegate.
   */
  function getShouldDelegate() internal view returns (bool shouldDelegate) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes32 _blob = StoreSwitch.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (_toBool(uint8(bytes1(_blob))));
  }

  /**
   * @notice Get shouldDelegate.
   */
  function _getShouldDelegate() internal view returns (bool shouldDelegate) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes32 _blob = StoreCore.getStaticField(_tableId, _keyTuple, 1, _fieldLayout);
    return (_toBool(uint8(bytes1(_blob))));
  }

  /**
   * @notice Set shouldDelegate.
   */
  function setShouldDelegate(bool shouldDelegate) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((shouldDelegate)), _fieldLayout);
  }

  /**
   * @notice Set shouldDelegate.
   */
  function _setShouldDelegate(bool shouldDelegate) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setStaticField(_tableId, _keyTuple, 1, abi.encodePacked((shouldDelegate)), _fieldLayout);
  }

  /**
   * @notice Get hookSystemIds.
   */
  function getHookSystemIds() internal view returns (bytes32[] memory hookSystemIds) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreSwitch.getDynamicField(_tableId, _keyTuple, 0);
    return (SliceLib.getSubslice(_blob, 0, _blob.length).decodeArray_bytes32());
  }

  /**
   * @notice Get hookSystemIds.
   */
  function _getHookSystemIds() internal view returns (bytes32[] memory hookSystemIds) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreCore.getDynamicField(_tableId, _keyTuple, 0);
    return (SliceLib.getSubslice(_blob, 0, _blob.length).decodeArray_bytes32());
  }

  /**
   * @notice Set hookSystemIds.
   */
  function setHookSystemIds(bytes32[] memory hookSystemIds) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setDynamicField(_tableId, _keyTuple, 0, EncodeArray.encode((hookSystemIds)));
  }

  /**
   * @notice Set hookSystemIds.
   */
  function _setHookSystemIds(bytes32[] memory hookSystemIds) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setDynamicField(_tableId, _keyTuple, 0, EncodeArray.encode((hookSystemIds)));
  }

  /**
   * @notice Get the length of hookSystemIds.
   */
  function lengthHookSystemIds() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreSwitch.getDynamicFieldLength(_tableId, _keyTuple, 0);
    unchecked {
      return _byteLength / 32;
    }
  }

  /**
   * @notice Get the length of hookSystemIds.
   */
  function _lengthHookSystemIds() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreCore.getDynamicFieldLength(_tableId, _keyTuple, 0);
    unchecked {
      return _byteLength / 32;
    }
  }

  /**
   * @notice Get an item of hookSystemIds.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function getItemHookSystemIds(uint256 _index) internal view returns (bytes32) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreSwitch.getDynamicFieldSlice(_tableId, _keyTuple, 0, _index * 32, (_index + 1) * 32);
      return (bytes32(_blob));
    }
  }

  /**
   * @notice Get an item of hookSystemIds.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function _getItemHookSystemIds(uint256 _index) internal view returns (bytes32) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreCore.getDynamicFieldSlice(_tableId, _keyTuple, 0, _index * 32, (_index + 1) * 32);
      return (bytes32(_blob));
    }
  }

  /**
   * @notice Push an element to hookSystemIds.
   */
  function pushHookSystemIds(bytes32 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.pushToDynamicField(_tableId, _keyTuple, 0, abi.encodePacked((_element)));
  }

  /**
   * @notice Push an element to hookSystemIds.
   */
  function _pushHookSystemIds(bytes32 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.pushToDynamicField(_tableId, _keyTuple, 0, abi.encodePacked((_element)));
  }

  /**
   * @notice Pop an element from hookSystemIds.
   */
  function popHookSystemIds() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.popFromDynamicField(_tableId, _keyTuple, 0, 32);
  }

  /**
   * @notice Pop an element from hookSystemIds.
   */
  function _popHookSystemIds() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.popFromDynamicField(_tableId, _keyTuple, 0, 32);
  }

  /**
   * @notice Update an element of hookSystemIds at `_index`.
   */
  function updateHookSystemIds(uint256 _index, bytes32 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = abi.encodePacked((_element));
      StoreSwitch.spliceDynamicData(_tableId, _keyTuple, 0, uint40(_index * 32), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Update an element of hookSystemIds at `_index`.
   */
  function _updateHookSystemIds(uint256 _index, bytes32 _element) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = abi.encodePacked((_element));
      StoreCore.spliceDynamicData(_tableId, _keyTuple, 0, uint40(_index * 32), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Get name.
   */
  function getName() internal view returns (string memory name) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreSwitch.getDynamicField(_tableId, _keyTuple, 1);
    return (string(_blob));
  }

  /**
   * @notice Get name.
   */
  function _getName() internal view returns (string memory name) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreCore.getDynamicField(_tableId, _keyTuple, 1);
    return (string(_blob));
  }

  /**
   * @notice Set name.
   */
  function setName(string memory name) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setDynamicField(_tableId, _keyTuple, 1, bytes((name)));
  }

  /**
   * @notice Set name.
   */
  function _setName(string memory name) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setDynamicField(_tableId, _keyTuple, 1, bytes((name)));
  }

  /**
   * @notice Get the length of name.
   */
  function lengthName() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreSwitch.getDynamicFieldLength(_tableId, _keyTuple, 1);
    unchecked {
      return _byteLength / 1;
    }
  }

  /**
   * @notice Get the length of name.
   */
  function _lengthName() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreCore.getDynamicFieldLength(_tableId, _keyTuple, 1);
    unchecked {
      return _byteLength / 1;
    }
  }

  /**
   * @notice Get an item of name.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function getItemName(uint256 _index) internal view returns (string memory) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreSwitch.getDynamicFieldSlice(_tableId, _keyTuple, 1, _index * 1, (_index + 1) * 1);
      return (string(_blob));
    }
  }

  /**
   * @notice Get an item of name.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function _getItemName(uint256 _index) internal view returns (string memory) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreCore.getDynamicFieldSlice(_tableId, _keyTuple, 1, _index * 1, (_index + 1) * 1);
      return (string(_blob));
    }
  }

  /**
   * @notice Push a slice to name.
   */
  function pushName(string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.pushToDynamicField(_tableId, _keyTuple, 1, bytes((_slice)));
  }

  /**
   * @notice Push a slice to name.
   */
  function _pushName(string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.pushToDynamicField(_tableId, _keyTuple, 1, bytes((_slice)));
  }

  /**
   * @notice Pop a slice from name.
   */
  function popName() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.popFromDynamicField(_tableId, _keyTuple, 1, 1);
  }

  /**
   * @notice Pop a slice from name.
   */
  function _popName() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.popFromDynamicField(_tableId, _keyTuple, 1, 1);
  }

  /**
   * @notice Update a slice of name at `_index`.
   */
  function updateName(uint256 _index, string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = bytes((_slice));
      StoreSwitch.spliceDynamicData(_tableId, _keyTuple, 1, uint40(_index * 1), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Update a slice of name at `_index`.
   */
  function _updateName(uint256 _index, string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = bytes((_slice));
      StoreCore.spliceDynamicData(_tableId, _keyTuple, 1, uint40(_index * 1), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Get description.
   */
  function getDescription() internal view returns (string memory description) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreSwitch.getDynamicField(_tableId, _keyTuple, 2);
    return (string(_blob));
  }

  /**
   * @notice Get description.
   */
  function _getDescription() internal view returns (string memory description) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    bytes memory _blob = StoreCore.getDynamicField(_tableId, _keyTuple, 2);
    return (string(_blob));
  }

  /**
   * @notice Set description.
   */
  function setDescription(string memory description) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setDynamicField(_tableId, _keyTuple, 2, bytes((description)));
  }

  /**
   * @notice Set description.
   */
  function _setDescription(string memory description) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setDynamicField(_tableId, _keyTuple, 2, bytes((description)));
  }

  /**
   * @notice Get the length of description.
   */
  function lengthDescription() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreSwitch.getDynamicFieldLength(_tableId, _keyTuple, 2);
    unchecked {
      return _byteLength / 1;
    }
  }

  /**
   * @notice Get the length of description.
   */
  function _lengthDescription() internal view returns (uint256) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    uint256 _byteLength = StoreCore.getDynamicFieldLength(_tableId, _keyTuple, 2);
    unchecked {
      return _byteLength / 1;
    }
  }

  /**
   * @notice Get an item of description.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function getItemDescription(uint256 _index) internal view returns (string memory) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreSwitch.getDynamicFieldSlice(_tableId, _keyTuple, 2, _index * 1, (_index + 1) * 1);
      return (string(_blob));
    }
  }

  /**
   * @notice Get an item of description.
   * @dev Reverts with Store_IndexOutOfBounds if `_index` is out of bounds for the array.
   */
  function _getItemDescription(uint256 _index) internal view returns (string memory) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _blob = StoreCore.getDynamicFieldSlice(_tableId, _keyTuple, 2, _index * 1, (_index + 1) * 1);
      return (string(_blob));
    }
  }

  /**
   * @notice Push a slice to description.
   */
  function pushDescription(string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.pushToDynamicField(_tableId, _keyTuple, 2, bytes((_slice)));
  }

  /**
   * @notice Push a slice to description.
   */
  function _pushDescription(string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.pushToDynamicField(_tableId, _keyTuple, 2, bytes((_slice)));
  }

  /**
   * @notice Pop a slice from description.
   */
  function popDescription() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.popFromDynamicField(_tableId, _keyTuple, 2, 1);
  }

  /**
   * @notice Pop a slice from description.
   */
  function _popDescription() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.popFromDynamicField(_tableId, _keyTuple, 2, 1);
  }

  /**
   * @notice Update a slice of description at `_index`.
   */
  function updateDescription(uint256 _index, string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = bytes((_slice));
      StoreSwitch.spliceDynamicData(_tableId, _keyTuple, 2, uint40(_index * 1), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Update a slice of description at `_index`.
   */
  function _updateDescription(uint256 _index, string memory _slice) internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    unchecked {
      bytes memory _encoded = bytes((_slice));
      StoreCore.spliceDynamicData(_tableId, _keyTuple, 2, uint40(_index * 1), uint40(_encoded.length), _encoded);
    }
  }

  /**
   * @notice Get the full data.
   */
  function get() internal view returns (ExperienceMetadataData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    (bytes memory _staticData, EncodedLengths _encodedLengths, bytes memory _dynamicData) = StoreSwitch.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Get the full data.
   */
  function _get() internal view returns (ExperienceMetadataData memory _table) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    (bytes memory _staticData, EncodedLengths _encodedLengths, bytes memory _dynamicData) = StoreCore.getRecord(
      _tableId,
      _keyTuple,
      _fieldLayout
    );
    return decode(_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function set(
    address contractAddress,
    bool shouldDelegate,
    bytes32[] memory hookSystemIds,
    string memory name,
    string memory description
  ) internal {
    bytes memory _staticData = encodeStatic(contractAddress, shouldDelegate);

    EncodedLengths _encodedLengths = encodeLengths(hookSystemIds, name, description);
    bytes memory _dynamicData = encodeDynamic(hookSystemIds, name, description);

    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using individual values.
   */
  function _set(
    address contractAddress,
    bool shouldDelegate,
    bytes32[] memory hookSystemIds,
    string memory name,
    string memory description
  ) internal {
    bytes memory _staticData = encodeStatic(contractAddress, shouldDelegate);

    EncodedLengths _encodedLengths = encodeLengths(hookSystemIds, name, description);
    bytes memory _dynamicData = encodeDynamic(hookSystemIds, name, description);

    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function set(ExperienceMetadataData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.contractAddress, _table.shouldDelegate);

    EncodedLengths _encodedLengths = encodeLengths(_table.hookSystemIds, _table.name, _table.description);
    bytes memory _dynamicData = encodeDynamic(_table.hookSystemIds, _table.name, _table.description);

    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Set the full data using the data struct.
   */
  function _set(ExperienceMetadataData memory _table) internal {
    bytes memory _staticData = encodeStatic(_table.contractAddress, _table.shouldDelegate);

    EncodedLengths _encodedLengths = encodeLengths(_table.hookSystemIds, _table.name, _table.description);
    bytes memory _dynamicData = encodeDynamic(_table.hookSystemIds, _table.name, _table.description);

    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.setRecord(_tableId, _keyTuple, _staticData, _encodedLengths, _dynamicData, _fieldLayout);
  }

  /**
   * @notice Decode the tightly packed blob of static data using this table's field layout.
   */
  function decodeStatic(bytes memory _blob) internal pure returns (address contractAddress, bool shouldDelegate) {
    contractAddress = (address(Bytes.getBytes20(_blob, 0)));

    shouldDelegate = (_toBool(uint8(Bytes.getBytes1(_blob, 20))));
  }

  /**
   * @notice Decode the tightly packed blob of dynamic data using the encoded lengths.
   */
  function decodeDynamic(
    EncodedLengths _encodedLengths,
    bytes memory _blob
  ) internal pure returns (bytes32[] memory hookSystemIds, string memory name, string memory description) {
    uint256 _start;
    uint256 _end;
    unchecked {
      _end = _encodedLengths.atIndex(0);
    }
    hookSystemIds = (SliceLib.getSubslice(_blob, _start, _end).decodeArray_bytes32());

    _start = _end;
    unchecked {
      _end += _encodedLengths.atIndex(1);
    }
    name = (string(SliceLib.getSubslice(_blob, _start, _end).toBytes()));

    _start = _end;
    unchecked {
      _end += _encodedLengths.atIndex(2);
    }
    description = (string(SliceLib.getSubslice(_blob, _start, _end).toBytes()));
  }

  /**
   * @notice Decode the tightly packed blobs using this table's field layout.
   * @param _staticData Tightly packed static fields.
   * @param _encodedLengths Encoded lengths of dynamic fields.
   * @param _dynamicData Tightly packed dynamic fields.
   */
  function decode(
    bytes memory _staticData,
    EncodedLengths _encodedLengths,
    bytes memory _dynamicData
  ) internal pure returns (ExperienceMetadataData memory _table) {
    (_table.contractAddress, _table.shouldDelegate) = decodeStatic(_staticData);

    (_table.hookSystemIds, _table.name, _table.description) = decodeDynamic(_encodedLengths, _dynamicData);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function deleteRecord() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreSwitch.deleteRecord(_tableId, _keyTuple);
  }

  /**
   * @notice Delete all data for given keys.
   */
  function _deleteRecord() internal {
    bytes32[] memory _keyTuple = new bytes32[](0);

    StoreCore.deleteRecord(_tableId, _keyTuple, _fieldLayout);
  }

  /**
   * @notice Tightly pack static (fixed length) data using this table's schema.
   * @return The static data, encoded into a sequence of bytes.
   */
  function encodeStatic(address contractAddress, bool shouldDelegate) internal pure returns (bytes memory) {
    return abi.encodePacked(contractAddress, shouldDelegate);
  }

  /**
   * @notice Tightly pack dynamic data lengths using this table's schema.
   * @return _encodedLengths The lengths of the dynamic fields (packed into a single bytes32 value).
   */
  function encodeLengths(
    bytes32[] memory hookSystemIds,
    string memory name,
    string memory description
  ) internal pure returns (EncodedLengths _encodedLengths) {
    // Lengths are effectively checked during copy by 2**40 bytes exceeding gas limits
    unchecked {
      _encodedLengths = EncodedLengthsLib.pack(
        hookSystemIds.length * 32,
        bytes(name).length,
        bytes(description).length
      );
    }
  }

  /**
   * @notice Tightly pack dynamic (variable length) data using this table's schema.
   * @return The dynamic data, encoded into a sequence of bytes.
   */
  function encodeDynamic(
    bytes32[] memory hookSystemIds,
    string memory name,
    string memory description
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(EncodeArray.encode((hookSystemIds)), bytes((name)), bytes((description)));
  }

  /**
   * @notice Encode all of a record's fields.
   * @return The static (fixed length) data, encoded into a sequence of bytes.
   * @return The lengths of the dynamic fields (packed into a single bytes32 value).
   * @return The dynamic (variable length) data, encoded into a sequence of bytes.
   */
  function encode(
    address contractAddress,
    bool shouldDelegate,
    bytes32[] memory hookSystemIds,
    string memory name,
    string memory description
  ) internal pure returns (bytes memory, EncodedLengths, bytes memory) {
    bytes memory _staticData = encodeStatic(contractAddress, shouldDelegate);

    EncodedLengths _encodedLengths = encodeLengths(hookSystemIds, name, description);
    bytes memory _dynamicData = encodeDynamic(hookSystemIds, name, description);

    return (_staticData, _encodedLengths, _dynamicData);
  }

  /**
   * @notice Encode keys as a bytes32 array using this table's field layout.
   */
  function encodeKeyTuple() internal pure returns (bytes32[] memory) {
    bytes32[] memory _keyTuple = new bytes32[](0);

    return _keyTuple;
  }
}

/**
 * @notice Cast a value to a bool.
 * @dev Boolean values are encoded as uint8 (1 = true, 0 = false), but Solidity doesn't allow casting between uint8 and bool.
 * @param value The uint8 value to convert.
 * @return result The boolean value.
 */
function _toBool(uint8 value) pure returns (bool result) {
  assembly {
    result := value
  }
}