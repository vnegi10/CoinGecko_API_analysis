This Pluto notebook contains Julia code that can be used to make API calls to CoinGecko, and fetch developer and community metrics for various cryptocurrencies.

## How to use?

Install Pluto.jl (if not done already) by executing the following commands in your Julia REPL:

    using Pkg
    Pkg.add("Pluto")
    using Pluto
    Pluto.run() 

Clone this repository, and open **CG_notebook.jl** via Pluto. The built-in package manager should automatically download the necessary packages for you when you run the notebook for the first time.