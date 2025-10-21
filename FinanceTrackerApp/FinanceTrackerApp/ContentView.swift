import SwiftUI

struct ContentView: View {
    @State private var isAnimating = false
    @State private var showMainApp = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App icon/logo
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // App name
                Text("Finance Tracker")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .delay(0.5),
                        value: isAnimating
                    )
                
                // Tagline
                Text("Track your finances with ease")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .delay(1.0),
                        value: isAnimating
                    )
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .delay(1.5),
                    value: isAnimating
                )
            }
            .padding()
        }
        .onAppear {
            isAnimating = true
            
            // Simulate loading time
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showMainApp = true
                }
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            MainAppView()
        }
    }
}

struct MainAppView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardScreen()
                .environmentObject(AuthViewModel.shared)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            AccountsScreen()
                .environmentObject(AuthViewModel.shared)
                .tabItem {
                    Label("Accounts", systemImage: "wallet.pass")
                }
                .tag(1)
            
            SubscriptionsScreen()
                .environmentObject(AuthViewModel.shared)
                .tabItem {
                    Label("Subscriptions", systemImage: "repeat")
                }
                .tag(2)
            
            RevenueScreen()
                .environmentObject(AuthViewModel.shared)
                .tabItem {
                    Label("Revenue", systemImage: "dollarsign.circle")
                }
                .tag(3)
            
            SettingsView()
                .environmentObject(AuthViewModel.shared)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

struct DashboardView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance Card
                    VStack(spacing: 12) {
                        HStack {
                            Text("Total Balance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "wallet.pass")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        
                        HStack {
                            Text("$0.00")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Across all accounts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Quick Stats
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Monthly Overview")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chart.bar")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .frame(width: 24)
                                
                                Text("Monthly Income")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("$0.00")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                    .frame(width: 24)
                                
                                Text("Monthly Expenses")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("$0.00")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .frame(width: 24)
                                
                                Text("Net Change")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("$0.00")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Welcome Message
                    VStack(spacing: 20) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Welcome to Finance Tracker")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your financial overview is ready. Add accounts, subscriptions, and revenue to see detailed projections.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct AccountsView: View {
    struct Account: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        let currency: Currency
    }
    
    enum Currency: String, CaseIterable, Identifiable {
        case usd = "USD"
        case eur = "EUR"
        case uah = "UAH"
        
        var id: String { rawValue }
        
        var symbol: String {
            switch self {
            case .usd: return "$"
            case .eur: return "€"
            case .uah: return "₴"
            }
        }
    }
    
    @State private var accounts: [Account] = []
    @State private var showAddAccountSheet = false
    @State private var newAccountName: String = ""
    @State private var newAccountAmount: String = ""
    @State private var newAccountCurrency: Currency = .usd
    
    private var amountFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if accounts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Accounts Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start by adding your financial accounts.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Add Account") {
                            showAddAccountSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(accounts) { account in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(account.name)
                                        .font(.headline)
                                    Text(account.currency.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(account.currency.symbol)\(String(format: "%.2f", account.amount))")
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddAccountSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddAccountSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Account Details")) {
                            TextField("Account Name", text: $newAccountName)
                            TextField("Amount", text: $newAccountAmount)
                                .keyboardType(.decimalPad)
                            Picker("Currency", selection: $newAccountCurrency) {
                                ForEach(Currency.allCases) { currency in
                                    Text(currency.rawValue).tag(currency)
                                }
                            }
                        }
                    }
                    .navigationTitle("Add Account")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                resetNewAccountFields()
                                showAddAccountSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveNewAccount()
                            }
                            .disabled(newAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(newAccountAmount.replacingOccurrences(of: ",", with: ".")) == nil)
                        }
                    }
                }
            }
        }
    }

    private func resetNewAccountFields() {
        newAccountName = ""
        newAccountAmount = ""
        newAccountCurrency = .usd
    }
    
    private func saveNewAccount() {
        let normalizedAmountString = newAccountAmount.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedAmountString) else { return }
        let account = Account(name: newAccountName.trimmingCharacters(in: .whitespacesAndNewlines), amount: amount, currency: newAccountCurrency)
        accounts.append(account)
        resetNewAccountFields()
        showAddAccountSheet = false
    }
}

struct SubscriptionsView: View {
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 20) {
                    Image(systemName: "repeat")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Subscriptions Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add your first subscription to start tracking recurring expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Add Subscription") {
                        // TODO: Show add subscription form
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Show add subscription form
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct RevenueView: View {
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 20) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Revenue Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Add your first revenue source to start tracking income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Add Revenue") {
                        // TODO: Show add revenue form
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Revenue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Show add revenue form
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Demo User")
                                .font(.headline)
                            
                            Text("demo@example.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Account") {
                    Button(action: {
                        // TODO: Sign out
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@financetracker.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact Support")
                        }
                    }
                    
                    Link(destination: URL(string: "https://financetracker.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}