import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer; // Import pustaka developer untuk logging
import 'dart:math';
import 'package:http/http.dart';
import 'package:qrypta/src/core/config/blockchain_config.dart';
import 'package:web3dart/web3dart.dart';
import 'package:convert/convert.dart';

class BlockchainService {
  late Web3Client _client;
  final String _serviceName = 'BlockchainService';

  BlockchainService() {
    _client = Web3Client(BlockchainConfig.rpcUrl, Client());
    developer.log(
      '[INFO] Service Initialized with RPC: ${BlockchainConfig.rpcUrl}',
      name: _serviceName,
    );
  }

  // --- Core Client Getter ---
  Web3Client get client => _client;

  // --- Native Currency Utilities ---

  Future<EtherAmount> getBalance(EthereumAddress address) async {
    developer.log(
      '[INFO] Fetching balance for: ${address.hex}',
      name: _serviceName,
    );
    try {
      final balance = await _client.getBalance(address);
      developer.log(
        '[INFO] Balance for ${address.hex} is ${balance.getInEther} ETH',
        name: _serviceName,
      );
      return balance;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching balance',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<BigInt> estimateTransactionFee({
    required EthereumAddress to,
    EtherAmount? value,
  }) async {
    developer.log('[INFO] Estimating fee to: ${to.hex}', name: _serviceName);
    try {
      final gasPrice = await _client.getGasPrice();
      final estimatedGasLimit = await _client.estimateGas(to: to, value: value);
      final totalFee = gasPrice.getInWei * estimatedGasLimit;
      developer.log('[INFO] Estimated fee: $totalFee Wei', name: _serviceName);
      return totalFee;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error estimating fee',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<String> sendTransaction(
    String privateKey,
    EthereumAddress receiver,
    EtherAmount amount,
  ) async {
    developer.log(
      '[INFO] Attempting to send ${amount.getInEther} ETH to ${receiver.hex}',
      name: _serviceName,
    );
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final transaction = Transaction(to: receiver, value: amount);
      final txHash = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: BlockchainConfig.chainId,
      );
      developer.log(
        '[INFO] Transaction sent successfully. Hash: $txHash',
        name: _serviceName,
      );
      return txHash;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error sending transaction',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // --- ERC-20 Token Utilities ---

  DeployedContract _getErc20Contract(String contractHex) {
    final contractAddress = EthereumAddress.fromHex(contractHex);
    final abi = [
      'function balanceOf(address owner) view returns (uint256)',
      'function transfer(address to, uint256 value) returns (bool)',
    ];
    return DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'ERC20'),
      contractAddress,
    );
  }

  Future<BigInt> getErc20Balance(String contractHex, String ownerHex) async {
    developer.log(
      '[INFO] Fetching ERC20 balance for $ownerHex on contract $contractHex',
      name: _serviceName,
    );
    try {
      final contract = _getErc20Contract(contractHex);
      final balanceFunction = contract.function('balanceOf');
      final ownerAddress = EthereumAddress.fromHex(ownerHex);
      final result = await _client.call(
        contract: contract,
        function: balanceFunction,
        params: [ownerAddress],
      );
      final balance = result.first as BigInt;
      developer.log('[INFO] ERC20 balance is $balance', name: _serviceName);
      return balance;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching ERC20 balance',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<String> sendErc20Token({
    required String privateKey,
    required String contractHex,
    required String recipientHex,
    required BigInt amount,
  }) async {
    developer.log(
      '[INFO] Attempting to send $amount ERC20 tokens to $recipientHex',
      name: _serviceName,
    );
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final contract = _getErc20Contract(contractHex);
      final transferFunction = contract.function('transfer');
      final recipientAddress = EthereumAddress.fromHex(recipientHex);
      final transaction = Transaction.callContract(
        contract: contract,
        function: transferFunction,
        parameters: [recipientAddress, amount],
      );
      final txHash = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: BlockchainConfig.chainId,
      );
      developer.log(
        '[INFO] ERC20 transaction sent successfully. Hash: $txHash',
        name: _serviceName,
      );
      return txHash;
    } catch (e, s) {
      developer.log(
        '[ERROR] Error sending ERC20 token',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // --- General Transaction Utilities ---

  Future<TransactionReceipt?> getTransactionReceipt(String txHash) async {
    developer.log(
      '[INFO] Fetching receipt for tx: $txHash',
      name: _serviceName,
    );
    try {
      return await _client.getTransactionReceipt(txHash);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching transaction receipt',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<TransactionReceipt> waitForTransactionReceipt(String txHash) async {
    developer.log(
      '[INFO] Waiting for receipt for tx: $txHash',
      name: _serviceName,
    );
    const pollInterval = Duration(seconds: 2);
    const timeout = Duration(minutes: 1);
    final completer = Completer<TransactionReceipt>();
    Timer.periodic(pollInterval, (timer) async {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      final receipt = await getTransactionReceipt(txHash);
      if (receipt != null) {
        developer.log(
          '[INFO] Receipt found for tx: $txHash',
          name: _serviceName,
        );
        timer.cancel();
        completer.complete(receipt);
      }
    });
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) {
          throw TimeoutException(
            'Transaction receipt lookup timed out for hash $txHash',
          );
        }
        return completer.future;
      },
    );
  }

  Future<int> getNonce(String addressHex) async {
    developer.log('[INFO] Fetching nonce for: $addressHex', name: _serviceName);
    try {
      final address = EthereumAddress.fromHex(addressHex);
      return await _client.getTransactionCount(address);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching nonce',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  Future<TransactionInformation?> getTransactionByHash(String txHash) async {
    developer.log(
      '[INFO] Fetching transaction info for: $txHash',
      name: _serviceName,
    );
    try {
      return await _client.getTransactionByHash(txHash);
    } catch (e, s) {
      developer.log(
        '[ERROR] Error fetching transaction info',
        name: _serviceName,
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  // --- Address & Wallet Utilities ---

  bool isValidAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      developer.log(
        '[ERROR] Invalid address format: $address',
        name: _serviceName,
        error: e,
      );
      return false;
    }
  }

  Future<EthereumAddress> getAddressFromPrivateKey(String privateKey) async {
    final credentials = EthPrivateKey.fromHex(privateKey);
    return credentials.address;
  }

  EthPrivateKey createRandomPrivateKey() {
    var rng = Random.secure();
    final key = EthPrivateKey.createRandom(rng);
    developer.log('[INFO] Created new random private key.', name: _serviceName);
    return key;
  }

  String getPrivateKeyHex(EthPrivateKey key) {
    return '0x${hex.encode(key.privateKey)}';
  }

  // --- General Utilities ---

  Future<void> dispose() async {
    developer.log(
      '[INFO] Disposing BlockchainService client.',
      name: _serviceName,
    );
    _client.dispose();
  }
}
