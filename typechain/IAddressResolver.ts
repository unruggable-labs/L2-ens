/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result, EventFragment } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export interface IAddressResolverInterface extends utils.Interface {
  functions: {
    "addr(bytes32,uint256)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "addr",
    values: [BytesLike, BigNumberish]
  ): string;

  decodeFunctionResult(functionFragment: "addr", data: BytesLike): Result;

  events: {
    "AddressChanged(bytes32,uint256,bytes)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "AddressChanged"): EventFragment;
}

export type AddressChangedEvent = TypedEvent<
  [string, BigNumber, string],
  { node: string; coinType: BigNumber; newAddress: string }
>;

export type AddressChangedEventFilter = TypedEventFilter<AddressChangedEvent>;

export interface IAddressResolver extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IAddressResolverInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    addr(
      node: BytesLike,
      coinType: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[string]>;
  };

  addr(
    node: BytesLike,
    coinType: BigNumberish,
    overrides?: CallOverrides
  ): Promise<string>;

  callStatic: {
    addr(
      node: BytesLike,
      coinType: BigNumberish,
      overrides?: CallOverrides
    ): Promise<string>;
  };

  filters: {
    "AddressChanged(bytes32,uint256,bytes)"(
      node?: BytesLike | null,
      coinType?: null,
      newAddress?: null
    ): AddressChangedEventFilter;
    AddressChanged(
      node?: BytesLike | null,
      coinType?: null,
      newAddress?: null
    ): AddressChangedEventFilter;
  };

  estimateGas: {
    addr(
      node: BytesLike,
      coinType: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    addr(
      node: BytesLike,
      coinType: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}