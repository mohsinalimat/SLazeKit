import Foundation
import SLazeKit
import CoreData

//First we gonna create NSManagedObject object on which we will work.

/// We assume you have Model as an NSManagedObject
class Model: NSManagedObject {}

// MARK: - Simulate extension for CoreData
extension Model {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Model> {
        return NSFetchRequest<Model>(entityName: "Model")
    }
    
    @NSManaged public var id: String
    @NSManaged public var value: Double
    @NSManaged public var name: String?
}


// MARK: - SLazeKit extension
extension Model {
    /// Path pattern for our model API requests
    public struct PathPattern {
        static var model: String { return "/api/Models/:modelId" }
        static var models: String { return "/api/Models" }
        static var create: String { return "/api/Models/:modelId/create" }
        static var delete: String { return "/api/Models/:modelId/delete" }
    }
    /// We are creating struct which represents Decodable response of API request
    /// `EntityMappingDecodable` is required
    public struct ModelResponse: EntityMappingDecodable {
        var id: String
        var value: Double
        var name: String?
        /// We need provide NSManagedObject type for our serialization.
        public static var entityType: NSManagedObject.Type {
            return Model.self
        }
        /// By providing id attributes our model are updated/created/serialized
        public var idAttributes: [EntityAttribute]? {
            return [
                ("id",id)
            ]
        }
        
        /// Fill CoreData object with our model response
        public func fillObject(with model: NSManagedObject) {
            guard let object = model as? Model else { return }
            object.id = id
            object.value = value
            object.name = name
        }
    }
    
    /// We could skip that and add `Encodable` to our ModelResponse. But to highlight it. We will create separate one for request purpose
    public struct ModelRequest: Encodable {
        var id: String
        var value: Double
        var name: String?
        //Convenience initializer.
        init(with model: Model) {
            self.id = model.id
            self.value = model.value
            self.name = model.name
        }
    }
}

extension Model {
    /// Create request. Called from SLazeKit. Response is not maped or serialized.
    ///
    /// - Parameters:
    ///   - model: CoreData model used to post request with body of ModelRequest
    class func create(model: Model, success: @escaping (() ->()), failure: ((_ statusCode: Int, _ error: Error?) ->())? = nil) {
        /// SLazeKit request are done i background. To handle response on main thread we need to dispatch it.
        let _ = SLazeKit.post(path: PathPattern.create.patternToPath(with: ["modelId":model.id]), body: ModelRequest(with: model)) { (response, error) in
            guard error == nil else {
                DispatchQueue.main.async { failure?(response?.statusCode ?? -1,error) }
                return
            }
            DispatchQueue.main.async { success() }
        }
    }
    /// Another request example with out mapping or serialization.
    ///
    /// - Parameters:
    ///   - modelId: model id used to replace key string in path pattern.
    class func remove(for modelId: String, success: @escaping (() ->()), failure: ((_ statusCode: Int, _ error: Error?) ->())? = nil) {
        /// SLazeKit request are done i background. To handle response on main thread we need to dispatch it.
        let _ = SLazeKit.delete(path: PathPattern.delete.patternToPath(with: ["modelId":modelId])) { (response, error) in
                                                                                    guard error == nil else {
                                                                                        DispatchQueue.main.async { failure?(response?.statusCode ?? -1,error) }
                                                                                        return
                                                                                    }
                                                                                    DispatchQueue.main.async { success() }
        }
    }
    /// `[ModelResponse]` Stands as a result type. Decodable provides generic requests. if Response model beside `Decodable` comforms to `EntityMapping` as well it will be serialized.
    class func getFromServer(success: @escaping (([Model]?) ->()), failure: (() ->())? = nil) {
        /// [ModelResponse] Decodable type used to generate result type.
        let _ = [ModelResponse].get(path: PathPattern.models.patternToPath()) { (response, result, error) in
            guard error == nil else {
                failure?()
                return
            }
            var models: [Model]? = nil
            do {
                //Result is type of `[ModelResponse]` to return array of our CoreData models we need to serialize it.
                //result?.serialized will return `[Model]`
                models = try result?.serialized(ModelResponse.persistentContainer?.newBackgroundContext())
            } catch {
                print(error)
            }
            success(models)
        }
    }
    
    class func getFromServer(for modelId: String, success: @escaping ((Model?) ->()), failure: (() ->())? = nil) {
        /// in this example API request will decode single object of type ModelResponse instead of an array.
        let _ = ModelResponse.get(path: PathPattern.model.patternToPath(with: ["modelId":modelId])) { (response, result, error) in
            guard error == nil else {
                failure?()
                return
            }
            var models: Model? = nil
            do {
                //Result of type `ModelResponse` to return CoreData model we need to serialize it.
                //result?.serialized will return `Model`
                models = try result?.serialized(ModelResponse.persistentContainer?.newBackgroundContext())
            } catch {
                print(error)
            }
            success(models)
        }
    }
}