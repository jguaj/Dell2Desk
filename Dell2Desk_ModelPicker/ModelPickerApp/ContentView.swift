	//
	//  ContentView.swift
	//  Dell2Desk
	//
	//  Created by Pavan Govu
	//

	import SwiftUI
	import RealityKit
	import ARKit
	import FocusEntity

	struct ContentView : View {
		@State private var isPlacement = false //toggles between model picker and placement buttons 
		@State private var selectedModel: Model? //will contain the name of the model that has been selected
		@State private var modelConfirmedForPlacement: Model? //set to model name if confirmed for placement
		
		private var models: [Model] = {
			// Dynamically get our model filename for easier integration 
			let filemanager = FileManager.default
			let path = Bundle.main.resourcePath
			
			//we "guard" against the possibility of no models loaded (error handling)
			guard let files = try?filemanager.contentsOfDirectory(atPath: path!) else {
			return []
			}
			
			//only pick files with usdz extension
			var avaliableModels: [Model] = []
			for filename in files where
				filename.hasSuffix("usdz") {
				let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
				let model = Model(modelName: modelName)
				avaliableModels.append(model)
			}
			
			return avaliableModels
		}()
		
		var body: some View {
	//        return ARViewContainer().edgesIgnoringSafeArea(.all)
	//        Text("Hello World")

			//allows us to arrange Dell models in a depth manner
			
			//TODO: implement horizontal stack + vertical stack
			ZStack(alignment: .bottom, content: {
				ARViewContainer(modelConfirmedForPlacement:     self.$modelConfirmedForPlacement).edgesIgnoringSafeArea(.all)
				
				//determine which view to show
				if self.isPlacement {
				
					//Note: $ gives read and write access to binding variable, as opposed to only read
					PlacementButtonView(isPlacement: self.$isPlacement, selectedModel: self.$selectedModel, modelConfirmedForPlacement: self.$modelConfirmedForPlacement)
				} else {
					ModelPickerView(isPlacement: self.$isPlacement, selectedModel: self.$selectedModel, models: self.models)
				}
			})
		}
	}

	struct ARViewContainer: UIViewRepresentable {
		@Binding var modelConfirmedForPlacement: Model?
		
		func makeUIView(context: Context) -> ARView {
			
	//        let arView = ARView(frame: .zero)
			
			// Load the "Box" scene from the "Experience" Reality File
	//        let boxAnchor = try! Experience.loadBox()

			// Add the box anchor to the scene
	//        arView.scene.anchors.append(boxAnchor)
			
	//        let config = ARWorldTrackingConfiguration()
	//        config.planeDetection = [.horizontal, .vertical]
	//        config.environmentTexturing = .automatic
	//
	//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
	//            config.sceneReconstruction = .mesh
	//        }
	//
	//        arView.session.run(config)
			
			let arView = FocusARView(frame: .zero)

			return arView
		}
		
		//adding models to the scene
		func updateUIView(_ uiView: ARView, context: Context) {
			
			//safely unwrap
			if let model = self.modelConfirmedForPlacement {
				if model.modelName == "teapot" {
					if let boxScene = try? Experience.loadBox() {
						boxScene.steelBox?.scale = [5, 0.1, 5]

						// Do something with box
						let physics = Physics()
						
						let boxEntity = boxScene.children[0].children[0].children[0]
	//                  boxEntity.name = "CUBE"
						print("DEBUG: boxEntity \(boxEntity)")
						
						let kinematicComponent: PhysicsBodyComponent = physics.physicsBody!
						let motionComponent: PhysicsMotionComponent = physics.physicsMotion!

						boxEntity.components.set(kinematicComponent)
						boxEntity.components.set(motionComponent)

						uiView.scene.anchors.append(boxScene)
					}
				} else {
					if let modelEntity = model.modelEntity {
						print("DEBUG: updateUIView \(model.modelName)")

						//in RealityKit, all objects have to be attached to an anchor
						let anchorEntity = AnchorEntity(plane: .any)

						anchorEntity.addChild(modelEntity.clone(recursive: true))
						
						uiView.scene.addAnchor(anchorEntity)
					} else {
						print("DEBUG: Unable to load \(model.modelName)")
					}
				}

				//circumvents issue of modifying binding var while UI is still processing it
				DispatchQueue.main.async {
					self.modelConfirmedForPlacement = nil
				}
			}
		}
	}

	class Physics: Entity, HasPhysicsBody, HasPhysicsMotion {
		required init() {
			super.init()

			self.physicsBody = PhysicsBodyComponent(massProperties: .default,
														  material: nil,
															  mode: .kinematic)

			self.physicsMotion = PhysicsMotionComponent(linearVelocity: [0.1, 0, 0],
													   angularVelocity: [1, 3, 5])
		}
	}

	class FocusARView: ARView {
		enum FocusStyleChoices {
		  case classic
		  case material
		  case color
		}

		/// Style to be displayed in the example
		let focusStyle: FocusStyleChoices = .classic
		var focusEntity: FocusEntity?

		required init(frame frameRect: CGRect) {
		  super.init(frame: frameRect)
		  self.setupConfig()

		  switch self.focusStyle {
		  case .color:
			self.focusEntity = FocusEntity(on: self, focus: .plane)
		  case .material:
			do {
			  let onColor: MaterialColorParameter = try .texture(.load(named: "Add"))
			  let offColor: MaterialColorParameter = try .texture(.load(named: "Open"))
			  self.focusEntity = FocusEntity(
				on: self,
				style: .colored(
				  onColor: onColor, offColor: offColor,
				  nonTrackingColor: offColor
				)
			  )
			} catch {
			  self.focusEntity = FocusEntity(on: self, focus: .classic)
			  print("Unable to load plane textures")
			  print(error.localizedDescription)
			}
		  default:
			self.focusEntity = FocusEntity(on: self, focus: .classic)
		  }
		}

		@objc required dynamic init?(coder decoder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		func setupConfig() {
			let config = ARWorldTrackingConfiguration()
			config.planeDetection = [.horizontal, .vertical]
			config.environmentTexturing = .automatic
			
			if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
				config.sceneReconstruction = .mesh
			}

			self.session.run(config)
		}
	}

	extension FocusARView: FocusEntityDelegate {
	  func toTrackingState() {
		print("tracking")
	  }
	  func toInitializingState() {
		print("initializing")
	  }
	}

	//created our own view for more elegant, modular solution
	struct ModelPickerView: View {
		@Binding var isPlacement: Bool
		@Binding var selectedModel: Model?
		
		var models: [Model]
		
		var body: some View {
			
			//horizontal sliding to additional models off screen
			ScrollView(.horizontal, showsIndicators: true, content: {
				HStack(spacing:10) {
					
					//loop through the various usdz models currently loaded
					ForEach(0 ..< self.models.count) {
						index in
						Button(action: {
							print("DEBUG: Selected model \(self.models[index].modelName)")
							
							//once model is selected
							self.selectedModel = self.models[index]
							
							self.isPlacement = true
						}) {
							Image(uiImage: self.models[index].image)
								//swift UI images are not resizable by default
								.resizable()
								.frame(height:80)
								.aspectRatio(1/1, contentMode:.fit)
								.background(Color.white)
								.cornerRadius(12)
						}
					}
				}
			})
			.padding(20) //20 pixels of padding in dock
			.background(Color.black.opacity(0.5))
		}
	}

	struct PlacementButtonView: View {
		@Binding var isPlacement: Bool
		@Binding var selectedModel: Model?
		@Binding var modelConfirmedForPlacement: Model?
		
		//cancel and confirm button
		var body: some View {
			HStack {
				// Cancel Button
				Button(action: {
					print("DEBUG: Canceled")
					//go back to model picker
					self.resetPlacementParameters()
				}) {
					Image(systemName: "xmark")
						.frame(width: 60, height: 60, alignment: .center)
						.font(.title)
						.background(Color.white.opacity(0.75))
						.cornerRadius(30)//half height to make it circular
						.padding(20)
				}
				
				// Confirm Button
				Button(action: {
					print("DEBUG: Confirmed")
					
					//pass on selected model to model confirmed for placement
					self.modelConfirmedForPlacement = self.selectedModel
					
					//go back to model picker
					self.resetPlacementParameters()
				}) {
					Image(systemName: "checkmark")
						.frame(width: 60, height: 60, alignment: .center)
						.font(.title)
						.background(Color.white.opacity(0.75))
						.cornerRadius(30) //half height to make it circular
						.padding(20)
				}
			}
		}
		
		//DRY: do not repeate yourself
		func resetPlacementParameters() {
			self.isPlacement = false
			self.selectedModel = nil //intuitive, no model selected
		}
	}

	#if DEBUG
	struct ContentView_Previews : PreviewProvider {
		static var previews: some View {
			ContentView()
		}
	}
	#endif
