import UIKit

private let reuseIdentifier = "ContactCell"

class ContactsController: UIViewController {

    @IBOutlet var contactsTable: UITableView!
    @IBOutlet var importFirstContactNotification: UILabel!
    @IBOutlet var selectMultipleButton: UIBarButtonItem!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    
    public var selectedContacts = [User]()
    
    private let realm = RealmInstance.getInstance()
    private let search = UISearchController(searchResultsController: nil)
    private let refreshControl = UIRefreshControl()
    private var contactsDictionary = [String:[User]]()
    private var contactsSectionTitles = [String]()
    private var filteredContacts = [User]()
    private var usersBoolean = [UserBoolean]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView(table: contactsTable, controller: self)

        setLargeNavigationBar(for: self)
        setSearchBar()
        setSelectButton()
        setToolbar()
        
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        contactsTable.addSubview(refreshControl)
        
        loadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        DispatchQueue.main.async {
            self.cancelSelection()
            self.contactsTable.reloadData()
        }
    }
    
    @objc func refresh(_ sender: Any) {
        loadData()
        refreshControl.endRefreshing()
    }

    @objc func deleteContacts(_ sender: Any) {
        let indexPaths = contactsTable.indexPathsForSelectedRows!
        for indexPath in indexPaths.reversed() {
            deleteContact(at: indexPath)
        }
        cancelSelection()
    }
    
    @objc func shareContacts(_ sender: Any) {
        DispatchQueue.main.async {
            var contactsInfo = [Any]()
            for contact in self.selectedContacts {
                guard let siteLink = URL(string: "http://www.cloudcards.h1n.ru/#\(contact.parentId)\(ID_SEPARATOR)\(contact.uuid)") else { return }
                let shareInfo = "\(contact.name) \(contact.surname) отправил(а) Вам свою визитку! Просмотрите её по ссылке:"
                contactsInfo.append(shareInfo)
                contactsInfo.append(siteLink)
            }
            
            let shareController = UIActivityViewController(activityItems: contactsInfo, applicationActivities: [])
            self.present(shareController, animated: true)
            
            self.cancelSelection()
        }
    }
    
    /*
        Кнопка для множественного выбора
     */
    
    @objc func selectMultiple(_ sender: Any) {
        if contactsTable.isEditing {
            self.contactsTable.deselectSelectedRows(animated: true)
            cancelSelection()
        } else {
            contactsTable.setEditing(true, animated: true)
            let cancelButton : UIBarButtonItem = UIBarButtonItem(
                title: "Готово",
                style: UIBarButtonItem.Style.plain,
                target: self,
                action: #selector(selectMultiple(_:))
            )
            cancelButton.tintColor = PRIMARY

            self.navigationItem.leftBarButtonItem = cancelButton
        }
    }
    
    /*
        Загрузка данных контактов
     */
    
    private func loadData() {
        contactsDictionary.removeAll()
        contactsSectionTitles.removeAll()
        selectedContacts.removeAll()
        
        let userDictionary = realm.objects(User.self)
        let ownerUuid = userDictionary.count > 0 ? userDictionary[0].uuid : String()
        usersBoolean = Array(realm.objects(UserBoolean.self).filter("parentId != \"\(ownerUuid)\""))
        usersBoolean.forEach { getUserFromDatabase(userBoolean: $0) }
        if usersBoolean.count == 0 {
            loadingIndicator.stopAnimating()
            self.importFirstContactNotification.isHidden = false
        }
    }
    
    /*
        Добавляет строку поиска в NavBar
     */

    private func setSearchBar() {
        search.searchResultsUpdater = self
        search.searchBar.placeholder = "Поиск"
        search.searchBar.setValue("Отмена", forKey: "cancelButtonText")
        search.dimsBackgroundDuringPresentation = false
        search.searchBar.scopeButtonTitles = ["Имя", "Фамилия", "Компания"]
        definesPresentationContext = true
        self.navigationItem.searchController = search
    }
    
    /*
        Нижний тулбар, появляется при множественном выборе визиток
     */
    
    private func setToolbar() {
        let trashButton = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(deleteContacts(_:))
        )
        trashButton.tintColor = PRIMARY
        
        let space = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: self,
            action: nil
        )
        
        let shareButton = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareContacts(_:))
        )
        shareButton.tintColor = PRIMARY
        
        navigationController?.toolbar.setItems([trashButton, space, shareButton], animated: true)
        navigationController?.toolbar.barTintColor = LIGHT_GRAY
        navigationController?.toolbar.isTranslucent = false
    }
    
    /*
        Сброс множественного выбора визиток
     */
    
    private func cancelSelection() {
        setSelectButton()
        selectedContacts.removeAll()
        navigationController?.isToolbarHidden = true
        contactsTable.setEditing(false, animated: true)
    }
    
    /*
        Установка кнопки множественного выбора визиток
     */
    
    private func setSelectButton() {
        let select : UIBarButtonItem = UIBarButtonItem(
            title: "Изм.",
            style: UIBarButtonItem.Style.plain,
            target: self,
            action: #selector(selectMultiple(_:))
        )
        select.tintColor = PRIMARY

        self.navigationItem.leftBarButtonItem = select
    }
    
    /*
         Получение данных контакта из Firebase
     */

    private func getUserFromDatabase(userBoolean: UserBoolean) {
        let firebaseClient = FirebaseClientInstance.getInstance()
        firebaseClient.getUser(firstKey: userBoolean.parentId, secondKey: userBoolean.parentId, firstKeyPath: FirestoreInstance.USERS, secondKeyPath: FirestoreInstance.DATA) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    let parentUser = convertFromDictionary(dictionary: data, type: User.self)
                    let currentUser = getUserFromTemplate(user: parentUser, userBoolean: userBoolean)

                    let contactKey = String(currentUser.surname.prefix(1))
                    if var contactValues = self.contactsDictionary[contactKey] {
                        contactValues.append(currentUser)
                        contactValues.sort(by: {$0.surname < $1.surname})
                        self.contactsDictionary[contactKey] = contactValues
                    } else {
                        self.contactsDictionary[contactKey] = [currentUser]
                    }

                    self.contactsSectionTitles = [String](self.contactsDictionary.keys)
                    self.contactsSectionTitles = self.contactsSectionTitles.sorted(by: {$0 < $1})
                    
                    if self.contactsDictionary.values.count == self.usersBoolean.count {
                        self.contactsTable.reloadData()
                    }
                case .failure(let error):
                    print(error)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension ContactsController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return searchIsActivated() ? 1 : contactsSectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchIsActivated() {
            return filteredContacts.count
        }
        
        let contactKey = contactsSectionTitles[section]
        if let contactValues = contactsDictionary[contactKey] {
            return contactValues.count
        }
        
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = contactsTable.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ContactCell

        if searchIsActivated() {
            cell.update(with: filteredContacts[indexPath.row])
        } else {
            let contactKey = contactsSectionTitles[indexPath.section]
            if let contactValues = contactsDictionary[contactKey] {
                cell.update(with: contactValues[indexPath.row])
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return searchIsActivated() ? nil : contactsSectionTitles[section]
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return searchIsActivated() ? nil : contactsSectionTitles
    }
}

// MARK: - UITableViewDelegate

extension ContactsController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        let contact = getUserFromRow(with: indexPath)

        if contactsTable.isEditing {
            selectedContacts.append(contact)

            cell.tintColor = PRIMARY
            
            if navigationController?.isToolbarHidden == true {
                navigationController?.isToolbarHidden = false
                setToolbar()
            }
        } else {
            let cardViewController = self.storyboard?.instantiateViewController(withIdentifier: "CardViewController") as! CardViewController
            cardViewController.currentUser = contact
            let nav = UINavigationController(rootViewController: cardViewController)
            navigationController?.showDetailViewController(nav, sender: nil)
            contactsTable.deselectSelectedRows(animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let lastVisibleIndexPath = tableView.indexPathsForVisibleRows?.last {
            if indexPath == lastVisibleIndexPath {
                loadingIndicator.stopAnimating()
                importFirstContactNotification.isHidden = self.contactsSectionTitles.count != 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let contact = getUserFromRow(with: indexPath)
        
        selectedContacts.remove(at: selectedContacts.firstIndex(of: contact)!)
        
        if selectedContacts.count == 0 {
            navigationController?.isToolbarHidden = true
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let qr = showQRAction(at: indexPath)
        let share = shareAction(at: indexPath)
        let delete = deleteAction(at: indexPath)
        return UISwipeActionsConfiguration(actions: [delete, share, qr])
    }
    
    private func getUserFromRow(with indexPath : IndexPath) -> User {
        if searchIsActivated() {
            return filteredContacts[indexPath.row]
        }
        let contactKey = contactsSectionTitles[indexPath.section]
        let contactValues = contactsDictionary[contactKey]
        return contactValues![indexPath.row]
    }
}

// MARK: - RowButtons

extension ContactsController {
    
    func showQRAction(at indexPath: IndexPath) -> UIContextualAction {
        let contact = getUserFromRow(with: indexPath)
        let action = UIContextualAction(style: .normal, title: "ShowQR") { (action, view, completion) in
            showShareController(with: contact, in: self)
            completion(true)
        }
        action.image = UIImage(systemName: "qrcode")
        action.backgroundColor = PRIMARY
        return action
    }
    
    func shareAction(at indexPath: IndexPath) -> UIContextualAction {
        let contact = getUserFromRow(with: indexPath)
        let action = UIContextualAction(style: .normal, title: "Share") { (action, view, completion) in
            showShareLinkController(with: contact, in: self)
            completion(true)
        }
        action.image = UIImage(systemName: "square.and.arrow.up")
        action.backgroundColor = GRAPHITE
        return action
    }
    
    func deleteAction(at indexPath: IndexPath) -> UIContextualAction {
        let action = UIContextualAction(style: .destructive, title: "Delete") { (action, view, completion) in
            self.deleteContact(at: indexPath)
            completion(true)
        }
        action.image = UIImage(systemName: "trash")
        return action
    }
    
    private func deleteContact(at indexPath: IndexPath) {
        let contact = getUserFromRow(with: indexPath)
        
        try! realm.write {
            realm.delete(realm.objects(UserBoolean.self).filter("uuid = \"\(contact.uuid)\""))
        }

        // Удаляем контакт из словаря контактов
        let contactKey = contactsSectionTitles[indexPath.section]
        contactsDictionary[contactKey]?.removeAll(where: { $0.uuid == contact.uuid })
        
        // Удаляем ячейку таблицы с данным контактом
        contactsTable.deleteRows(at: [indexPath], with: .automatic)
        
        // Если на первую букву фамилии никого больше нет, то удаляем сначала букву из списка,
        // а уже после удаляем секцию в самой таблице, отображаемой на экране
        if !contactsDictionary[contactKey]!.contains(where: { $0.surname.prefix(1) == contact.surname.prefix(1) }) {
            contactsSectionTitles.removeAll(where: { $0 == String(contact.surname.prefix(1)) })
            let indexSet = IndexSet(arrayLiteral: indexPath.section)
            contactsTable.deleteSections(indexSet, with: .automatic)
        }
        
        importFirstContactNotification.isHidden = contactsSectionTitles.count != 0
    }
}

// MARK: - UISearchResultsUpdating

extension ContactsController: UISearchResultsUpdating {
    
    func filterContacts(for searchText: String) {
        let contactsArrays = contactsDictionary.values
        var contacts = [User]()
        
        contactsArrays.forEach { users in
            contacts.append(contentsOf: users)
        }
        
        filteredContacts.removeAll()
        
        switch search.searchBar.selectedScopeButtonIndex {
        case 1:
            contacts.forEach { contact in
                if contact.surname.lowercased().contains(searchText.lowercased()) {
                    filteredContacts.append(contact)
                }
            }
        case 2:
            contacts.forEach { contact in
                if contact.company.lowercased().contains(searchText.lowercased()) {
                    filteredContacts.append(contact)
                }
            }
        default:
            contacts.forEach { contact in
                if contact.name.lowercased().contains(searchText.lowercased()) {
                    filteredContacts.append(contact)
                }
            }
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        DispatchQueue.main.async {
            self.filterContacts(for: searchController.searchBar.text ?? String())
            
            self.contactsTable.reloadData()
        }
    }
    
    func searchIsActivated() -> Bool {
        return search.isActive && search.searchBar.text != ""
    }
}

// MARK: - UISearchBarDelegate

extension ContactsController: UISearchBarDelegate {
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.setShowsCancelButton(false, animated: true)
        return true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.main.async {
            searchBar.resignFirstResponder()
            self.contactsTable.reloadData()
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        updateSearchResults(for: search)
    }
}
