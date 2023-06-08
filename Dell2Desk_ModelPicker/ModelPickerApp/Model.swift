//
//  Model.swift
//  ModelPickerApp
//
//  Created by Pavan
//

import UIKit
import RealityKit
import Combine //apple's asynchronous event driven framework

//contains everything we need to display thumnails & objects
//fixes asynchronous loading in updateView
class Model {
    var modelName:String
    var image:UIImage
    var modelEntity: ModelEntity? //optional in case of nil
    
    private var cancellabel: AnyCancellable? = nil
    
    init(modelName: String) {
        self.modelName = modelName
        
        self.image = UIImage(named: modelName)! //force unwrap because we know thumnail existsx
        
		//asynchronous load
        let filename = modelName + ".usdz"
        self.cancellabel = ModelEntity.loadModelAsync(named: filename)
            .sink(receiveCompletion: {loadCompletion in
			//handle error
                print("DEBUG: unable to load modelEntity \(self.modelName)")
            }, receiveValue: {modelEntity in
			//get model entity
                self.modelEntity = modelEntity
                print("DEBUG: Succesefully loaded modelEntity \(self.modelName)")
            })
    }
}
