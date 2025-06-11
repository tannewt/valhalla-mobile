import ValhallaObjc
import ValhallaModels
import ValhallaConfigModels
import os.log

public protocol ValhallaProviding {
    
    init(_ config: ValhallaConfig) throws
    
    init(configPath: String) throws

    func route(request: RouteRequest) throws -> RouteResponse
}

public final class Valhalla: ValhallaProviding {
    private let actor: ValhallaWrapper?
    private let configPath: String
    private static let logger = Logger(subsystem: "Valhalla", category: "routing")

    public convenience init(_ config: ValhallaConfig) throws {
        Self.logger.info("Initializing Valhalla with config")
        let configURL = try ValhallaFileManager.saveConfigTo(config)
        try self.init(configPath: configURL.relativePath)
    }

    public required init(configPath: String) throws {
        Self.logger.info("Initializing Valhalla with config path: \(configPath)")
        do {
            try ValhallaFileManager.injectTzdataIntoLibrary()
        } catch {
            // If you're circumventing this libraries injection, download tzdata.tar and put in your bundle. https://www.iana.org/time-zones
            fatalError("tzdata was not inject into Bundle.main. This can be avoided by including tzdata.tar in your main bundle.")
        }

        self.configPath = configPath
        do {
            self.actor = try ValhallaWrapper(configPath: configPath)
            Self.logger.info("Valhalla actor initialized successfully")
        } catch let error as NSError {
            Self.logger.error("Failed to initialize Valhalla actor: \(error.domain) code: \(error.code)")
            throw ValhallaError.valhallaError(error.code, error.domain)
        } catch {
            Self.logger.error("Failed to initialize Valhalla actor: \(error.localizedDescription)")
            throw ValhallaError.valhallaError(-1, error.localizedDescription)
        }
    }
    
    public func route(request: RouteRequest) throws -> RouteResponse {
        Self.logger.info("Starting route calculation")
        let requestData = try JSONEncoder().encode(request)
        guard let requestStr = String(data: requestData, encoding: .utf8) else {
            Self.logger.error("Failed to encode request to UTF-8")
            throw ValhallaError.encodingNotUtf8("requestStr")
        }
        
        Self.logger.debug("Sending route request: \(requestStr)")
        let resultStr = route(rawRequest: requestStr)
        Self.logger.debug("Received route response: \(resultStr)")
        
        guard let resultData = resultStr.data(using: .utf8) else {
            Self.logger.error("Failed to decode response from UTF-8")
            throw ValhallaError.encodingNotUtf8("resultData")
        }
        
        if let error = try? JSONDecoder().decode(ValhallaErrorModel.self, from: resultData) {
            Self.logger.error("Route calculation failed: \(error.message)")
            throw ValhallaError.valhallaError(error.code, error.message)
        }
        
        Self.logger.info("Route calculation completed successfully")
        return try JSONDecoder().decode(RouteResponse.self, from: resultData)
    }

    public func route(rawRequest request: String) -> String {
        Self.logger.debug("Processing raw route request")
        Self.logger.debug("Timezone version: \(TimeZone.timeZoneDataVersion)")
        let result = actor!.route(request)!
        Self.logger.debug("Raw route request completed")
        return result
    }
}
