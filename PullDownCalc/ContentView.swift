//
//  ContentView.swift
//  PullDownCalc
//
//  Created by 森田健太 on 2024/10/27.
//

import SwiftUI

struct Formula: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    var expression: String
}

class CalculatorViewModel: ObservableObject {
    @Published var formulas: [Formula] = []
    @Published var calculationHistory: [String] = []
    
    init() {
        formulas = [
            Formula(name: "足し算", expression: "a + b"),
            Formula(name: "引き算", expression: "a - b"),
            Formula(name: "掛け算", expression: "a * b"),
            Formula(name: "割り算", expression: "a / b"),
            Formula(name: "二次方程式の解", expression: "(-b + sqrt(b*b - 4*a*c)) / (2*a)")
        ]
    }
}

struct ContentView: View {
    @StateObject var viewModel = CalculatorViewModel()
    
    var body: some View {
        TabView {
            CalculationView()
                .tabItem {
                    Label("計算", systemImage: "calculator")
                }
                .environmentObject(viewModel)
            FormulaListView()
                .tabItem {
                    Label("計算式", systemImage: "list.bullet")
                }
                .environmentObject(viewModel)
        }
    }
}

struct CalculationView: View {
    @EnvironmentObject var viewModel: CalculatorViewModel
    @State private var selectedFormula: Formula?
    @State private var variableValues: [String: String] = [:]
    @State private var result: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Form {
                    Picker("計算式を選択", selection: $selectedFormula) {
                        ForEach(viewModel.formulas) { formula in
                            Text(formula.name).tag(formula as Formula?)
                        }
                    }
                    .onChange(of: selectedFormula) { _ in
                        variableValues = [:]
                        result = ""
                    }
                    
                    if let formula = selectedFormula {
                        let variables = extractVariables(from: formula.expression)
                        ForEach(variables, id: \.self) { variable in
                            HStack {
                                Text("\(variable):")
                                TextField("⬜︎", text: Binding(
                                    get: { variableValues[variable, default: ""] },
                                    set: { variableValues[variable] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                            }
                        }
                        
                        Button("計算する") {
                            calculateResult()
                            hideKeyboard()
                        }
                    }
                }
                
                if !result.isEmpty {
                    Text("結果: \(result)")
                        .font(.title)
                        .padding()
                }
                
                List {
                    ForEach(viewModel.calculationHistory, id: \.self) { history in
                        Text(history)
                    }
                }
                
                Button("リフレッシュ") {
                    viewModel.calculationHistory.removeAll()
                }
                .padding()
            }
            .navigationTitle("計算機")
        }
    }
    
    func extractVariables(from expression: String) -> [String] {
        let pattern = "[a-zA-Z]+"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: expression, range: NSRange(expression.startIndex..., in: expression))
        let variables = matches.map { String(expression[Range($0.range, in: expression)!]) }
        let functionsAndConstants: Set<String> = ["sqrt", "sin", "cos", "tan", "exp", "log", "pi", "e"]
        let variableSet = Set(variables).subtracting(functionsAndConstants)
        return Array(variableSet).sorted()
    }
    
    func calculateResult() {
        guard let formula = selectedFormula else { return }
        
        // 変数の値を準備
        var variablesDict: [String: Double] = [:]
        for (variable, value) in variableValues {
            if let number = Double(value) {
                variablesDict[variable] = number
            } else {
                result = "\(variable)に有効な数値を入力してください"
                return
            }
        }
        
        // 式を作成して評価
        let expressionString = formula.expression
        let expr = NSExpression(format: expressionString)
        if let value = expr.expressionValue(with: variablesDict, context: nil) as? NSNumber {
            result = value.stringValue
            let historyEntry = "\(formula.name): \(result)"
            viewModel.calculationHistory.append(historyEntry)
        } else {
            result = "計算エラー"
        }
    }
    
    // キーボードを閉じるメソッドを追加
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct FormulaListView: View {
    @EnvironmentObject var viewModel: CalculatorViewModel
    @State private var showingAddFormula = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.formulas) { formula in
                    VStack(alignment: .leading) {
                        Text(formula.name)
                            .font(.headline)
                        Text(formula.expression)
                            .font(.subheadline)
                    }
                }
                .onDelete(perform: deleteFormula)
            }
            .navigationTitle("計算式一覧")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddFormula = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFormula) {
                AddFormulaView()
                    .environmentObject(viewModel)
            }
        }
    }
    
    func deleteFormula(at offsets: IndexSet) {
        viewModel.formulas.remove(atOffsets: offsets)
    }
}

struct AddFormulaView: View {
    @EnvironmentObject var viewModel: CalculatorViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var name: String = ""
    @State private var expression: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("計算式の名前")) {
                    TextField("名前を入力", text: $name)
                }
                Section(header: Text("計算式")) {
                    TextField("例: (a + b) * c", text: $expression)
                }
            }
            .navigationTitle("計算式を追加")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveFormula()
                    }
                    .disabled(name.isEmpty || expression.isEmpty)
                }
            }
        }
    }
    
    func saveFormula() {
        let newFormula = Formula(name: name, expression: expression)
        viewModel.formulas.append(newFormula)
        presentationMode.wrappedValue.dismiss()
    }
}
