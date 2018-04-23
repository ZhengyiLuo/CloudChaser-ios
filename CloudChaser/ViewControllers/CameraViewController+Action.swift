//
//  CameraViewController+Action.swift
//  StreamIt
//
//  Created by Zen on 4/22/18.
//  Copyright © 2018 Thibault Wittemberg. All rights reserved.
//

import Foundation
import UIKit

extension CameraViewController: UIPopoverPresentationControllerDelegate, VirtualObjectSelectionViewControllerDelegate {
    
    // MARK: - UIPopoverPresentationControllerDelegate
    enum SegueIdentifier: String {
        case showOptions
    }
    
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // All menus should be popovers (even on iPhone).
        if let popoverController = segue.destination.popoverPresentationController, let button = sender as? UIButton {
            popoverController.delegate = self
            popoverController.sourceView = button
            popoverController.sourceRect = button.bounds
        }
        
        guard let identifier = segue.identifier,
            let segueIdentifer = SegueIdentifier(rawValue: identifier),
            segueIdentifer == .showOptions else { return }
        
        let objectsViewController = segue.destination as! VirtualObjectSelectionViewController
        
        
        objectsViewController.virtualObjects = VirtualObject.availableObjects
        
        
        objectsViewController.delegate = self
        self.objectsViewController = objectsViewController
        
        // Set all rows of currently placed objects to selected.
//        for object in virtualObjectLoader.loadedObjects {
//            guard let index = VirtualObject.availableObjects.index(of: object) else { continue }
//            objectsViewController.selectedVirtualObjectRows.insert(index)
//        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        objectsViewController = nil
    }
    
    // MARK: - VirtualObjectSelectionViewControllerDelegate
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didSelectObject object: VirtualObject) {
        switch object.modelName{
        case "connect":
            connectToChase()
        case "disconnect":
            disconnectToChase()
        case "reset":
            reset()
        default:
            return 
        }
//        virtualObjectLoader.loadVirtualObject(object, loadedHandler: { [unowned self] loadedObject in
//            DispatchQueue.main.async {
//                self.hideObjectLoadingUI()
//                self.placeVirtualObject(loadedObject)
//            }
//        })
//
//        displayObjectLoadingUI()
        
    }
    
    func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, didDeselectObject object: VirtualObject) {
//        guard let objectIndex = virtualObjectLoader.loadedObjects.index(of: object) else {
//            fatalError("Programmer error: Failed to lookup virtual object in scene.")
//        }
//        virtualObjectLoader.removeVirtualObject(at: objectIndex)
//        virtualObjectInteraction.selectedObject = nil
//        if let anchor = object.anchor {
//            session.remove(anchor: anchor)
//        }
    }
}
