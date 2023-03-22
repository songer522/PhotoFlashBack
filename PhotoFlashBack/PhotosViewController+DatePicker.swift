//
//  PhotosViewController+DatePicker.swift
//  PhotoFlashBack
//
//  Created by Yang Song on 9/28/22.
//

import UIKit

extension PhotosViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
    {
        let pickerLabel = UILabel()
        pickerLabel.textColor = UIColor.white
        switch component {
                    case 0:
            pickerLabel.text = viewModel.monthArray[row]
            

                        //return monthArray[row]
                    case 1:
                        pickerLabel.text = String(row + 1)
                        //return String(row + 1)
                    default:
                        pickerLabel.text = ""
        }
        pickerLabel.textAlignment = NSTextAlignment.center
        return pickerLabel
    }
    
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0:
            return 12
        case 1:
            return 31
        default :
            return 0
        }
        
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            viewModel.month = row + 1
        case 1:
            viewModel.day = row + 1
        default:
        break
        }
        if viewModel.month == 2 {
            if viewModel.day == 30 || viewModel.day == 31 {
                viewModel.day = 29
                pickerView.selectRow(28, inComponent: 1, animated: true)
                
                
            }
        } else if viewModel.month == 6 || viewModel.month == 9 || viewModel.month == 4 || viewModel.month == 11 {
            if viewModel.day == 31 {
                viewModel.day = 30
                pickerView.selectRow(29, inComponent: 1, animated: true)
            }
        }

        
    }
}
