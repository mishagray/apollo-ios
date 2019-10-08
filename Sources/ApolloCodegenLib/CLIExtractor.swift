//
//  CLIExtractor.swift
//  ApolloCodegenLib
//
//  Created by Ellen Shapiro on 10/3/19.
//  Copyright © 2019 Apollo GraphQL. All rights reserved.
//

import Foundation

struct CLIExtractor {
  
  // MARK: - Extracting the binary
  
  enum CLIExtractorError: Error {
    case couldNotGetSHASUM
    case noBinaryFolderAfterUnzipping(atURL: URL)
    case zipFileHasInvalidSHASUM(expectedSHASUM: String, gotSHASUM: String)
    case zipFileNotPresent(atURL: URL)
  }
  
  static let expectedSHASUM = "13febaa462e56679099d81502d530e16c3ddf1c6c2db06abe3822c0ef79fb9d2"
  
  static func extractCLIIfNeeded(from scriptsFolderURL: URL, expectedSHASUM: String = CLIExtractor.expectedSHASUM) throws -> URL {
    let apolloFolderURL = self.apolloFolderURL(fromScripts: scriptsFolderURL)
    
    guard FileManager.default.apollo_folderExists(at: apolloFolderURL) else {
      CodegenLogger.log("Apollo folder doesn't exist, extracting CLI from zip file.")
      return try self.extractCLIFromZip(scriptsFolderURL: scriptsFolderURL)
    }
    
    guard try self.validateSHASUMInExtractedFile(apolloFolderURL: apolloFolderURL, expected: expectedSHASUM) else {
      CodegenLogger.log("SHASUM of extracted zip does not match expected, deleting existing folder and re-extracting.")
      try FileManager.default.apollo_deleteFolder(at: apolloFolderURL)
      return try self.extractCLIFromZip(scriptsFolderURL: scriptsFolderURL)
    }
    
    let binaryFolderURL = self.binaryFolderURL(fromApollo: apolloFolderURL)
    let binaryURL = self.binaryURL(fromBinaryFolder: binaryFolderURL)
    guard FileManager.default.apollo_fileExists(at: binaryURL) else {
      CodegenLogger.log("There was a valid `.shasum` file, but no binary at the expected path. Deleting existing apollo folder and re-extracting.", logLevel: .warning)
      try FileManager.default.apollo_deleteFolder(at: apolloFolderURL)
      return try self.extractCLIFromZip(scriptsFolderURL: scriptsFolderURL, expectedSHASUM: expectedSHASUM)
    }
    
    CodegenLogger.log("Binary already extracted!")
    return binaryFolderURL
  }
  
  static func validateSHASUMInExtractedFile(apolloFolderURL: URL, expected: String = CLIExtractor.expectedSHASUM) throws -> Bool {
    let shasumFileURL = self.shasumFileURL(fromApollo: apolloFolderURL)
    let contents = try String(contentsOf: shasumFileURL, encoding: .utf8)
    
    guard contents == expected else {
      return contents.hasPrefix(expected)
    }
    
    return true
  }
  
  static func writeSHASUMToFile(apolloFolderURL: URL) throws {
    let shasumFileURL = self.shasumFileURL(fromApollo: apolloFolderURL)
    try CLIExtractor.expectedSHASUM.write(to: shasumFileURL,
                                          atomically: false,
                                          encoding: .utf8)
  }
  
  static func extractCLIFromZip(scriptsFolderURL: URL, expectedSHASUM: String = CLIExtractor.expectedSHASUM) throws -> URL {
    let zipFileURL = self.zipFileURL(fromScripts: scriptsFolderURL)

    try self.validateZipFileSHASUM(at: zipFileURL, expected: expectedSHASUM)
    
    CodegenLogger.log("Extracting CLI from zip file. This may take a second...")

    //    tar xzf "${SCRIPT_DIR}"/apollo.tar.gz -C "${SCRIPT_DIR}"
    
    _ = try Basher.run(command: "tar xzf \(zipFileURL.path) -C \(scriptsFolderURL.path)", from: nil)
    
    let apolloFolderURL = self.apolloFolderURL(fromScripts: scriptsFolderURL)
    let binaryFolderURL = self.binaryFolderURL(fromApollo: apolloFolderURL)
    
    guard FileManager.default.apollo_folderExists(at: binaryFolderURL) else {
      throw CLIExtractorError.noBinaryFolderAfterUnzipping(atURL: binaryFolderURL)
    }
    
    try self.writeSHASUMToFile(apolloFolderURL: apolloFolderURL)
    
    return binaryFolderURL
  }
  
  static func validateZipFileSHASUM(at zipFileURL: URL, expected: String = CLIExtractor.expectedSHASUM) throws {
    let shasum = try FileManager.default.apollo_shasum(at: zipFileURL)    
    guard shasum == expected else {
      throw CLIExtractorError.zipFileHasInvalidSHASUM(expectedSHASUM: expected, gotSHASUM: shasum)
    }
  }
  
  // MARK: - File/Folder URL helpers
  
  static func apolloFolderURL(fromScripts scriptsFolderURL: URL) -> URL {
    return scriptsFolderURL.appendingPathComponent("apollo")
  }
  
  static func zipFileURL(fromScripts scriptsFolderURL: URL) -> URL {
    return scriptsFolderURL.appendingPathComponent("apollo.tar.gz")
  }
  
  static func binaryFolderURL(fromApollo apolloFolderURL: URL) -> URL {
    return apolloFolderURL.appendingPathComponent("bin")
  }
  
  static func binaryURL(fromBinaryFolder binaryFolderURL: URL) -> URL {
    return binaryFolderURL.appendingPathComponent("run")
  }
  
  static func shasumFileURL(fromApollo apolloFolderURL: URL) -> URL {
    return apolloFolderURL.appendingPathComponent(".shasum")
  }
}