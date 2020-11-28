import UIKit

private let reuseIdentifier = "DataCell"
private let reuseIdentifierCardParameters = "CardParametersCell"

class CreateCardController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var createProfileNotification: UILabel!
    
    private let realm = RealmInstance.getInstance()
    private let cardParameters = ["Название визитки", "ЦВЕТ"]
    // Массив данных пользователя: 1 элемент - 1 вид данных
    private var data = [DataItem]()
    // Массив выбранных данных пользователя для создания визитки
    private var selectedItems = [DataItem]()
    private var selectedColor = String()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView(table: tableView, controller: self)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: reuseIdentifierCardParameters)
        tableView.setEditing(true, animated: true)
        setLargeNavigationBar(for: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        selectedColor = String()
        selectedItems.removeAll()
        
        /*
            Получение данных пользователя
         */
        
        let userDictionary = realm.objects(User.self)
        if userDictionary.count != 0 {
            let owner = userDictionary[0]
            data = setDataToList(user: owner)
            createProfileNotification.isHidden = true
        } else {
            data = [DataItem]()
            createProfileNotification.isHidden = false
        }
        
        tableView.reloadData()
    }

    @IBAction func saveCardToTemplates(_ sender: Any) {
        let title = tableView.cellForRow(at: IndexPath(row: 0, section: 0))?.textLabel?.text
        
        if selectedItems.count == 0 {
            showSimpleAlert(
                controller: self,
                title: "Данные не выбраны",
                message: "Вы не выбрали ни одного поля!"
            )
            return
        }
        
        if title == cardParameters[0] {
            showSimpleAlert(
                controller: self,
                title: "Название не указано",
                message: "Введите название визитки!"
            )
            return
        }
        
        saveCard(
            withTitle: title,
            withColor: selectedColor,
            withUserData: selectedItems
        )
        // Получение TemplatesController (Nav -> Tab -> Nav -> Cards)
        self.navigationController?.presentingViewController?.children.first?.children.first?.viewWillAppear(true)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func closeWindow(_ sender: Any) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    private func showEnterCardNameAlert() {
        let alert = UIAlertController(title: "Имя визитки", message: "Введите имя визитки", preferredStyle: .alert)
        let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))
        
        alert.addTextField { (textField) in
            textField.autocapitalizationType = .sentences
            textField.clearButtonMode = .whileEditing
            textField.text = cell?.textLabel?.text == self.cardParameters[0] ? String() : cell?.textLabel?.text
        }

        alert.addAction(UIAlertAction(title: "ОК", style: .default, handler: { [weak alert] (_) in
            var cardName = alert?.textFields![0].text
            cell?.textLabel?.textColor = .black
            if cardName == String() {
                cardName = self.cardParameters[0]
                cell?.textLabel?.textColor = .lightGray
            }
            cell?.textLabel?.text = cardName
        }))
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))

        self.present(alert, animated: true, completion: nil)
    }
}

extension CreateCardController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Свойста визитки"
        } else if section == 1 {
            return "Данные визитки"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return setCardParametersCell(for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! DataCell
        
        let dataCell = data[indexPath.row]
        cell.titleLabel?.text = dataCell.title
        cell.dataLabel?.text = dataCell.description
        
        let view = UIView()
        view.backgroundColor = .clear
        cell.selectedBackgroundView = view

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        if indexPath.section == 0 {
            tableView.deselectRow(at: indexPath, animated: false)
            if indexPath.row == 1 {
                selectedColor = COLORS[Int.random(in: 0..<COLORS.count)]
                print(selectedColor)
                cell.imageView?.tintColor = UIColor.init(hexString: selectedColor)
                return
            }
            showEnterCardNameAlert()
            return
        }
    
        let dataCell = data[indexPath.row]
    
        cell.tintColor = PRIMARY
        
        selectedItems.append(DataItem(title: dataCell.title, description: dataCell.description))
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let dataCell = data[indexPath.row]
        selectedItems.removeAll(where: { $0.title == dataCell.title })
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 1 {
            return true
        }
        return false
    }
    
    private func setCardParametersCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifierCardParameters, for: indexPath)
        cell.textLabel?.text = cardParameters[indexPath.row]
        cell.textLabel?.textColor = .lightGray
        cell.selectionStyle = .none
        if indexPath.row == 1 {
            cell.accessoryType = .disclosureIndicator
            selectedColor = COLORS[0]
            cell.imageView?.image = UIImage.init(systemName: "square.fill")
            cell.imageView?.tintColor = UIColor.init(hexString: selectedColor)
        } else {
            cell.textLabel?.font = UIFont.systemFont(ofSize: 21.0, weight: .regular)
        }
        return cell
    }
}

extension CreateCardController: UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return cardParameters.count
        }
        return data.count
    }
}