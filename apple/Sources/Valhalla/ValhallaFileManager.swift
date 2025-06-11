import Foundation
import ValhallaConfigModels
import Light_Swift_Untar
import os.log

enum ValhallaFileManagerError: Error {
    case tzdataNotFound
    case systemDirNotFound(String)
}

enum ValhallaFileManager {
    private static let logger = Logger(subsystem: "ValhallaFileManager", category: "routing")
    
    static func saveConfigTo(_ config: ValhallaConfig) throws -> URL {
        guard let applicationDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ValhallaFileManagerError.systemDirNotFound("applicationSupport")
        }
        try FileManager.default.createDirectory(at: applicationDir, withIntermediateDirectories: true)
        let configURL = applicationDir.appendingPathComponent("valhalla-config.json")
        let data = try JSONEncoder().encode(config)

        try data.write(to: configURL)
        return configURL
    }

    /// Add tzdata to the Library directory
    ///
    /// The HowardHinnant/date library used in valhalla requires the tzdata.tar file to be stored
    /// in Bundle.main. When the tar is manually added that way, the c++ library will extract this
    /// into the Library directory on run. This function provides a workaround for this by injecting
    /// our own resource tzdata.tar into the Library directory before any balhalla action runs.
    ///
    /// Learn more see <https://github.com/HowardHinnant/date>
    /// and <https://howardhinnant.github.io/date/tz.html#Installation>
    static func injectTzdataIntoLibrary() throws {
        guard let tzdataFileURL = Bundle.module.url(forResource: "tzdata", withExtension: "tar") else {
            throw ValhallaFileManagerError.tzdataNotFound
        }
        Self.logger.info("tzdata file url: \(tzdataFileURL)")

        guard let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            throw ValhallaFileManagerError.systemDirNotFound("library")
        }

        let tzdataFileData = try Data(contentsOf: tzdataFileURL)
        Self.logger.info("tzdata file size: \(tzdataFileData.count) bytes")
        let libraryURL = libraryDir.appendingPathComponent("tzdata")

        // Write the tar to Library/tzdata
        // TODO: We can create our own tar extract here if we want to avoid the dependency
        let result = try FileManager.default.createFilesAndDirectories(url: libraryURL, tarData: tzdataFileData)
        Self.logger.info("Loaded tzdata: \(result)")
        let tzDataVersion = libraryURL.appendingPathComponent("version")
        // Open the version file and print it out
        if let versionData = try? Data(contentsOf: tzDataVersion),
           let versionString = String(data: versionData, encoding: .utf8) {
            Self.logger.info("tzdata version: \(versionString)")
        } else {
            Self.logger.warning("Could not read tzdata version file")
        }
    }
}
