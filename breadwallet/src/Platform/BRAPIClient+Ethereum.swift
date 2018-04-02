//
//  BRAPIClient+Ethereum.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-03-12.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

extension BRAPIClient {
    
    // MARK: -
    public func getBalance(address: EthAddress, handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(request: JSONRPCRequest(method: "eth_getBalance", params: JSONRPCParams([address, "latest"])), handler: handler)
    }
    
    public func getGasPrice(handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(request: JSONRPCRequest(method: "eth_gasPrice", params: JSONRPCParams([])), handler: handler)
    }
    
    public func estimateGas(transaction: TransactionParams, handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(request: JSONRPCRequest(method: "eth_estimateGas", params: JSONRPCParams([transaction, "pending"])), handler: handler)
    }
    
    public func sendRawTransaction(rawTx: String, handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(request: JSONRPCRequest(method: "eth_sendRawTransaction", params: JSONRPCParams([rawTx])), handler: handler)
    }

    public func getEthTxList(address: EthAddress, handler: @escaping ([EthTx])->Void) {
        let host = E.isTestnet ? "ropsten.etherscan.io" : "api.etherscan.io"
        let url = URL(string: "http://\(host)/api?module=account&action=txlist&address=\(address)&sort=desc")!
        let req = URLRequest(url: url)
        //var req = URLRequest(url: url("/ethq/\(network)/query?module=account&action=txlist&address=\(address)"))
        //req.httpMethod = "POST" TODO:ETH = remove etherscan
        dataTaskWithRequest(req, authenticated: true, retryCount: 0, handler: { data, response, error in
            guard let json = data else { return }
            let decoder = JSONDecoder()
            do {
                let response = try decoder.decode(EthTxList.self, from: json)
                handler(response.result)
            } catch let e {
                print("error: \(e)")
            }

        }).resume()
    }
    
    // MARK: -
    
    private func send<ResultType>(request rpcRequest: JSONRPCRequest, handler: @escaping (JSONRPCResult<ResultType>) -> Void) {
        var encodedData: Data
        do {
            encodedData = try JSONEncoder().encode(rpcRequest)
        } catch (let jsonError) {
            return handler(.error(.jsonError(error: jsonError)))
        }
        
        var req = URLRequest(url: url("/ethq/\(network)/proxy"))
        req.httpMethod = "POST"
        req.httpBody = encodedData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, response, error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    return handler(.error(.httpError(error: error)))
                }
                guard let data = data else {
                    return handler(.error(.httpError(error: nil)))
                }
                
                var rpcResponse: JSONRPCResponse<ResultType>
                
                do {
                    rpcResponse = try JSONRPCResponse<ResultType>.from(data: data)
                } catch (let jsonError) {
                    return handler(.error(.jsonError(error: jsonError)))
                }
                
                if let rpcError = rpcResponse.error {
                    return handler(.error(.rpcError(error: rpcError)))
                } else {
                    return handler(.success(rpcResponse.result!))
                }
            }
            }.resume()
    }
    
    private var network: String {
        return (E.isTestnet || E.isRunningTests) ? "ropsten" : "mainnet"
    }
}