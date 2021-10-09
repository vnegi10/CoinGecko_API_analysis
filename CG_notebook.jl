### A Pluto.jl notebook ###
# v0.16.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ f768fb2e-254e-11ec-3df3-2b3faf840347
using PlutoUI, DataFrames, HTTP, JSON, Query, PlotlyJS, Dates, CSV

# ╔═╡ a87d0e17-7064-4f1a-9598-ba594350de3e
md"## Developer and Community Metrics for Blockchain Projects"

# ╔═╡ db77584e-aa56-466d-9c48-8980694d3d70
md" > **Author: Vikas Negi**
>
> [LinkedIn] (https://www.linkedin.com/in/negivikas/)
"

# ╔═╡ d0d43a31-defb-4f51-befe-3c11b3e8fb7f
md"
## Pkg environment
"

# ╔═╡ b9822868-91a2-431b-ae92-0aac9de2c683
md"
## Functions to access Coingecko API
"

# ╔═╡ a36126f6-1505-46e8-b330-9071dc025f9e
const URL = "https://api.coingecko.com/api/v3"

# ╔═╡ d634d55d-d8eb-4cc4-af0d-80a35af7a84d
md"
### Return API response
"

# ╔═╡ e4719579-0d17-4b54-a9b5-21a8efbe1819
function get_API_response(params::String, url::String = URL)
	
	CG_request = HTTP.request("GET", url * params; verbose = 0, retries = 2)
	response_text = String(CG_request.body)
	response_dict = JSON.parse(response_text)
	
	return response_dict
end

# ╔═╡ 03b3a0e2-4750-4f5c-89f4-e1d5ab9897ea
md"
### Test API by pinging server
"

# ╔═╡ 85ba3750-b976-4101-8c8d-70f523b6d250
get_API_response("/ping")

# ╔═╡ a18c2307-cb12-447d-b438-6db39d9a73e2
md"
### Get coin ID
"

# ╔═╡ 9fffc1e8-29f8-4eb9-a769-648b1f615984
function get_coin_id(currency::String)
	
	# Check if "data" folder exists, if not, create a new one
    if isdir("data")
        @info "data folder exists, cleanup action will be performed!"
    else
        mkdir("data")
        @info "New data folder has been created"
    end

    date = Dates.today()

    filename = "List_of_all_coins_$(date).csv"
    filepath = joinpath("data", filename)

    df_coins, df_filter, df_filter_1 = [DataFrame() for i = 1:3]

    # Look for present day's CSV file, if not found, download and save data to a new file
    if isfile(filepath)
        @info "Reading list of coins from CSV file on disk"
        df_coins = CSV.File(filepath) |> DataFrame        
    else
        try 
            @info "Fetching list of coins from CoinGecko"  
            coins_dict = get_API_response("/coins/list")
            df_coins = vcat(DataFrame.(coins_dict)...) 
            CSV.write(filepath, df_coins)           
        catch
            @info "Could not fetch data, try again later!"          
        end         
    end 

    # Return valid coin id only when list of coins is available
    if ~isempty(df_coins)

        # Filter on matching currency 
        df_filter = df_coins |> @filter(_.symbol == currency) |> DataFrame

        try
            # For multiple matches, first filter on coin ids and then on names,
            # which do not have "-" in them
            if size(df_filter)[1] > 1

                df_filter_1 = df_filter |> 
                            @filter(~occursin("-", _.id)) |> DataFrame

                if isempty(df_filter_1)
                    df_filter_1 = df_filter |> 
                            @filter(~occursin("-", _.name)) |> DataFrame
                end

                return df_filter_1[!, :id][1]
            end
            
            return df_filter[!, :id][1]

        catch err
            if isa(err, BoundsError)
                @info "Could not find an id for the given currency"
            else
                @info "Something went wrong, check this error: $(err)"
            end
        end

    else
        return ""   
    end
end

# ╔═╡ 8b22311d-aaac-427d-a5f8-7a2e5e421c60
get_coin_id("eth")

# ╔═╡ 506f7612-7776-4c08-ac21-41644be860ea
md"
### Convert dict to DataFrame
"

# ╔═╡ dd9913e7-710c-47d6-b217-5911e25e4d41
function dict_to_df(data_dict::Dict, df::DataFrame)

    # Collect only the key-value pairs where value is a number, hence suitable for plotting
    for key in collect(keys(data_dict))            
        if ~isnothing(data_dict[key]) && length(data_dict[key]) == 1
            push!(df, [key Float64(data_dict[key])])
        end		
    end

    return df
end

# ╔═╡ 1ccb18d2-ef80-4bc7-974d-d031e6994de8
md"
### Get developer and community data
"

# ╔═╡ 35ee3257-90aa-4540-8946-a8da70e15614
function get_dev_comm_data(currency::String)

    coin_id = get_coin_id(currency)

    coin_dict, dev_dict, comm_dict = [Dict() for i = 1:3]

    try
        @info "Fetching coin data from CoinGecko" 
        coin_dict = get_API_response("/coins/$(coin_id)")        
    catch
        @info "Could not fetch data, try again later!" 
    end

    # Get developer data
    try
        dev_dict = coin_dict["developer_data"]
    catch err     
        if isa(err, KeyError)
            @info "Could not find developer data!"
        else
            @info "This is a new error: $(err)"
        end
    end

    # Get community data
    try
        comm_dict = coin_dict["community_data"]
    catch err     
        if isa(err, KeyError)
            @info "Could not find community data!"
        else
            @info "This is a new error: $(err)"
        end
    end

    # Convert dict to DataFrame
    df_dev, df_comm = [DataFrame(Metric = String[], Value = Float64[]) for i = 1:2]

    if ~isempty(dev_dict)
        df_dev = dict_to_df(dev_dict, df_dev)         
    end

    if ~isempty(comm_dict) 
        df_comm = dict_to_df(comm_dict, df_comm)        	
    end

    return df_dev, df_comm
end

# ╔═╡ a549c06f-9c82-4da0-9d55-e8df004361d3
coin_dict = get_API_response("/coins/ethereum") 

# ╔═╡ 53a101c9-36e5-4a0b-a895-87ae0c846b79
md"
## Plot data
"

# ╔═╡ 4c5f23aa-5221-4b13-8654-331aa1d3121d
function plot_dev_comm_data(currency::String, data::String)

    # Convert currency symbol to lowercase and fetch data from CoinGecko
    df_dev, df_comm = get_dev_comm_data(lowercase(currency))
	
	# Filter row containing specific issue metric
	get_df_row(issues::String, df::DataFrame=df_dev) = df |> 
	                          @filter(_.Metric == issues) |> DataFrame
	
	# Calculate ratio of closed_issues / total_issues	
	get_value(issues::String) = get_df_row(issues)[!, :Value][1]
	
	dev_ratio =  get_value("closed_issues") / get_value("total_issues")

    # Developer data 
    trace1 = PlotlyJS.bar(; x = df_dev[!, :Metric], y = df_dev[!, :Value], 
                            name = "Developer data")

    # Community data 
    trace2 = PlotlyJS.bar(; x = df_comm[!, :Metric], y = df_comm[!, :Value], 
                            name = "Community data")
	
	layout = Layout(;title = "",
                xaxis = attr(title="", showgrid=true, zeroline=true, automargin=true),
                xaxis_tickangle = -22.5,
                yaxis = attr(title="Value", showgrid=true, zeroline=true),
                height = 500,
                width = 650,) 
	
	if data == "dev"
		layout["title"] = "Developer metrics for $(currency), activity ratio = $(round(dev_ratio, digits = 2))"	
		
		return Plot(trace1, layout)		
	else
		layout["title"] = "Community metrics for $(currency)"
		
		return Plot(trace2, layout)
	end
	
end

# ╔═╡ 5bc78a4a-ad2e-4210-9fde-f4f90d965416
currencies = sort(["BTC", "LTC", "BCH", "ETH", "KNC", "LINK", "ETC", "BNB", "ADA", "XTZ","EOS", "XRP", "XLM", "ZEC", "DASH", "XMR", "DOT", "UNI", "SOL", "MATIC", "THETA", "OMG", "ALGO", "GRT", "AAVE", "FIL", "BAT", "ZRX", "COMP"])

# ╔═╡ 8e8e424c-4dc8-41dc-98ed-f2218f49f089
md"
**Select currency**
"

# ╔═╡ c0389038-b9a7-46e2-9437-14a7f161c7e8
 @bind currency Select(currencies, default = "BTC")

# ╔═╡ 5e3ddba3-2c80-4031-949b-9d240bf824a3
plot_dev_comm_data(currency, "dev")

# ╔═╡ c37790b2-c7ac-41f1-8ee7-aaf3327af86a
plot_dev_comm_data(currency, "comm")

# ╔═╡ 2b01d10f-ac30-41e8-a19b-76b7d9c3ec18
md"
### Cleanup old files
"

# ╔═╡ 9a13a391-441f-4015-a5d3-8125cb284da4
function remove_old_files()
    # Cleanup data files from previous days
    try
        main_dir = pwd()
        cd("data")
        files = readdir()
        rx1 = "data"
        rx2 = "List"
        rx3 = ".csv"
        rx4 = ".txt"
        for file in files
            ts = Dates.unix2datetime(stat(file).mtime)
            file_date = Date(ts)
            if file_date != Dates.today() && (occursin(rx3, file) || occursin(rx4, file)) &&
                                             (occursin(rx1, file) || occursin(rx2, file))
                rm(file)
            end
        end
        cd(main_dir)    
    catch
        @info "Unable to perform cleanup action"
    end
end

# ╔═╡ c41ec10c-2063-4041-9be8-b15e0cfc21de
remove_old_files()

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Dates = "ade2ca70-3891-5945-98fb-dc099432e06a"
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
PlotlyJS = "f0f68f2c-4968-5e81-91da-67840de0976a"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Query = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"

[compat]
CSV = "~0.9.5"
DataFrames = "~1.2.2"
HTTP = "~0.9.16"
JSON = "~0.21.2"
PlotlyJS = "~0.16.0"
PlutoUI = "~0.7.14"
Query = "~1.0.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[AssetRegistry]]
deps = ["Distributed", "JSON", "Pidfile", "SHA", "Test"]
git-tree-sha1 = "b25e88db7944f98789130d7b503276bc34bc098e"
uuid = "bf4720bc-e11a-5d0c-854e-bdca1663c893"
version = "0.1.0"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BinDeps]]
deps = ["Libdl", "Pkg", "SHA", "URIParser", "Unicode"]
git-tree-sha1 = "1289b57e8cf019aede076edab0587eb9644175bd"
uuid = "9e28174c-4ba2-5203-b857-d8d62c4213ee"
version = "1.0.2"

[[Blink]]
deps = ["Base64", "BinDeps", "Distributed", "JSExpr", "JSON", "Lazy", "Logging", "MacroTools", "Mustache", "Mux", "Reexport", "Sockets", "WebIO", "WebSockets"]
git-tree-sha1 = "08d0b679fd7caa49e2bca9214b131289e19808c0"
uuid = "ad839575-38b3-5650-b840-f874b8c74a25"
version = "0.12.5"

[[CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "15b18ea098a4b5af316df529c2ff4055fcef36e9"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.9.5"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "31d0151f5716b655421d9d75b7fa74cc4e744df2"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.39.0"

[[Crayons]]
git-tree-sha1 = "3f71217b538d7aaee0b69ab47d9b7724ca8afa0d"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.0.4"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "d785f42445b63fc86caa08bb9a9351008be9b765"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.2.2"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "7d9d316f04214f7efdbb6398d545446e246eff02"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.10"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[DataValues]]
deps = ["DataValueInterfaces", "Dates"]
git-tree-sha1 = "d88a19299eba280a6d062e135a43f00323ae70bf"
uuid = "e7dc6d0d-1eca-5fa6-8ad6-5aecde8b7ea5"
version = "0.4.13"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "a32185f5428d3986f47c2ab78b1f216d5e6cc96f"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.5"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[FilePathsBase]]
deps = ["Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "7fb0eaac190a7a68a56d2407a6beff1142daf844"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.12"

[[FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[FunctionalCollections]]
deps = ["Test"]
git-tree-sha1 = "04cb9cfaa6ba5311973994fe3496ddec19b6292a"
uuid = "de31a74c-ac4f-5751-b3fd-e18cd04993ca"
version = "0.5.0"

[[Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "14eece7a3308b4d8be910e265c724a6ba51a9798"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.16"

[[Hiccup]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "6187bb2d5fcbb2007c39e7ac53308b0d371124bd"
uuid = "9fb69e20-1954-56bb-a84f-559cc56a8ff7"
version = "0.2.2"

[[HypertextLiteral]]
git-tree-sha1 = "72053798e1be56026b81d4e2682dbe58922e5ec9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.0"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "19cb49649f8c41de7fea32d089d37de917b553da"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.0.1"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[IterableTables]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Requires", "TableTraits", "TableTraitsUtils"]
git-tree-sha1 = "70300b876b2cebde43ebc0df42bc8c94a144e1b4"
uuid = "1c8ee90f-4401-5389-894e-7a04a3dc0f4d"
version = "1.0.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "642a199af8b68253517b80bd3bfd17eb4e84df6e"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.3.0"

[[JSExpr]]
deps = ["JSON", "MacroTools", "Observables", "WebIO"]
git-tree-sha1 = "bd6c034156b1e7295450a219c4340e32e50b08b1"
uuid = "97c1335a-c9c5-57fe-bc5d-ec35cebe8660"
version = "0.5.3"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[Kaleido_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "2ef87eeaa28713cb010f9fb0be288b6c1a4ecd53"
uuid = "f7e6163d-2fa5-5f23-b69c-1db539e41963"
version = "0.1.0+0"

[[LaTeXStrings]]
git-tree-sha1 = "c7f1c695e06c01b95a67f0cd1d34994f3e7db104"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.2.1"

[[Lazy]]
deps = ["MacroTools"]
git-tree-sha1 = "1370f8202dac30758f3c345f9909b97f53d87d3f"
uuid = "50d2b5c4-7a5e-59d5-8109-a42b560f39c0"
version = "0.15.1"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "5a5bc6bf062f0f95e62d0fe0a2d99699fed82dd9"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.8"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[Mustache]]
deps = ["Printf", "Tables"]
git-tree-sha1 = "36995ef0d532fe08119d70b2365b7b03d4e00f48"
uuid = "ffc61752-8dc7-55ee-8c37-f3e9cdd09e70"
version = "1.0.10"

[[Mux]]
deps = ["AssetRegistry", "Base64", "HTTP", "Hiccup", "Pkg", "Sockets", "WebSockets"]
git-tree-sha1 = "82dfb2cead9895e10ee1b0ca37a01088456c4364"
uuid = "a975b10e-0019-58db-a62f-e48ff68538c9"
version = "0.7.6"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Observables]]
git-tree-sha1 = "fe29afdef3d0c4a8286128d4e45cc50621b1e43d"
uuid = "510215fc-4207-5dde-b226-833fc4488ee2"
version = "0.4.0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "a8709b968a1ea6abc2dc1967cb1db6ac9a00dfb6"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.0.5"

[[Pidfile]]
deps = ["FileWatching", "Test"]
git-tree-sha1 = "1be8660b2064893cd2dae4bd004b589278e4440d"
uuid = "fa939f87-e72e-5be4-a000-7fc836dbe307"
version = "1.2.0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotlyBase]]
deps = ["Base64", "Dates", "DelimitedFiles", "DocStringExtensions", "JSON", "Kaleido_jll", "LaTeXStrings", "Logging", "Parameters", "Pkg", "REPL", "Requires", "Statistics", "UUIDs"]
git-tree-sha1 = "fd1b34c4306de3f324adb012253099efb6125922"
uuid = "a03496cd-edff-5a9b-9e67-9cda94a718b5"
version = "0.6.7"

[[PlotlyJS]]
deps = ["Blink", "DelimitedFiles", "JSExpr", "JSON", "Markdown", "Pkg", "PlotlyBase", "REPL", "Reexport", "Requires", "WebIO"]
git-tree-sha1 = "e668d85a1d5fd677172c18d8ac4a53e274b0c9b0"
uuid = "f0f68f2c-4968-5e81-91da-67840de0976a"
version = "0.16.4"

[[PlutoUI]]
deps = ["Base64", "Dates", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "d1fb76655a95bf6ea4348d7197b22e889a4375f4"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.14"

[[PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a193d6ad9c45ada72c14b731a318bedd3c2f00cf"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.3.0"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "00cfd92944ca9c760982747e9a1d0d5d86ab1e5a"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.2"

[[PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "6330e0c350997f80ed18a9d8d9cb7c7ca4b3a880"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.2.0"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Query]]
deps = ["DataValues", "IterableTables", "MacroTools", "QueryOperators", "Statistics"]
git-tree-sha1 = "a66aa7ca6f5c29f0e303ccef5c8bd55067df9bbe"
uuid = "1a8c2f83-1ff3-5112-b086-8aa67b057ba1"
version = "1.0.0"

[[QueryOperators]]
deps = ["DataStructures", "DataValues", "IteratorInterfaceExtensions", "TableShowUtils"]
git-tree-sha1 = "911c64c204e7ecabfd1872eb93c49b4e7c701f02"
uuid = "2aef5ad7-51ca-5a8f-8e88-e75cf067b44b"
version = "0.9.3"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "4036a3bd08ac7e968e27c203d45f5fff15020621"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.1.3"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "54f37736d8934a12a200edea2f9206b03bdf3159"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.7"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableShowUtils]]
deps = ["DataValues", "Dates", "JSON", "Markdown", "Test"]
git-tree-sha1 = "14c54e1e96431fb87f0d2f5983f090f1b9d06457"
uuid = "5e66a065-1f0a-5976-b372-e0b8c017ca10"
version = "0.2.5"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[TableTraitsUtils]]
deps = ["DataValues", "IteratorInterfaceExtensions", "Missings", "TableTraits"]
git-tree-sha1 = "78fecfe140d7abb480b53a44f3f85b6aa373c293"
uuid = "382cd787-c1b6-5bf2-a167-d5b971a19bda"
version = "1.0.2"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "1162ce4a6c4b7e31e0e6b14486a6986951c73be9"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.5.2"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[URIParser]]
deps = ["Unicode"]
git-tree-sha1 = "53a9f49546b8d2dd2e688d216421d050c9a31d0d"
uuid = "30578b45-9adc-5946-b283-645ec420af67"
version = "0.4.1"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "c69f9da3ff2f4f02e811c3323c22e5dfcb584cfa"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.1"

[[WebIO]]
deps = ["AssetRegistry", "Base64", "Distributed", "FunctionalCollections", "JSON", "Logging", "Observables", "Pkg", "Random", "Requires", "Sockets", "UUIDs", "WebSockets", "Widgets"]
git-tree-sha1 = "5fe32e4086d49f7ab9b087296742859f3ae6d62a"
uuid = "0f1e0344-ec1d-5b48-a673-e5cf874b6c29"
version = "0.8.16"

[[WebSockets]]
deps = ["Base64", "Dates", "HTTP", "Logging", "Sockets"]
git-tree-sha1 = "f91a602e25fe6b89afc93cf02a4ae18ee9384ce3"
uuid = "104b5d7c-a370-577a-8038-80a2059c5097"
version = "1.5.9"

[[Widgets]]
deps = ["Colors", "Dates", "Observables", "OrderedCollections"]
git-tree-sha1 = "80661f59d28714632132c73779f8becc19a113f2"
uuid = "cc8bc4a8-27d6-5769-a93b-9d913e69aa62"
version = "0.6.4"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─a87d0e17-7064-4f1a-9598-ba594350de3e
# ╟─db77584e-aa56-466d-9c48-8980694d3d70
# ╟─d0d43a31-defb-4f51-befe-3c11b3e8fb7f
# ╠═f768fb2e-254e-11ec-3df3-2b3faf840347
# ╟─b9822868-91a2-431b-ae92-0aac9de2c683
# ╠═a36126f6-1505-46e8-b330-9071dc025f9e
# ╟─d634d55d-d8eb-4cc4-af0d-80a35af7a84d
# ╟─e4719579-0d17-4b54-a9b5-21a8efbe1819
# ╟─03b3a0e2-4750-4f5c-89f4-e1d5ab9897ea
# ╠═85ba3750-b976-4101-8c8d-70f523b6d250
# ╟─a18c2307-cb12-447d-b438-6db39d9a73e2
# ╟─9fffc1e8-29f8-4eb9-a769-648b1f615984
# ╠═8b22311d-aaac-427d-a5f8-7a2e5e421c60
# ╟─506f7612-7776-4c08-ac21-41644be860ea
# ╟─dd9913e7-710c-47d6-b217-5911e25e4d41
# ╟─1ccb18d2-ef80-4bc7-974d-d031e6994de8
# ╟─35ee3257-90aa-4540-8946-a8da70e15614
# ╠═a549c06f-9c82-4da0-9d55-e8df004361d3
# ╟─53a101c9-36e5-4a0b-a895-87ae0c846b79
# ╟─4c5f23aa-5221-4b13-8654-331aa1d3121d
# ╠═5bc78a4a-ad2e-4210-9fde-f4f90d965416
# ╠═5e3ddba3-2c80-4031-949b-9d240bf824a3
# ╟─8e8e424c-4dc8-41dc-98ed-f2218f49f089
# ╠═c0389038-b9a7-46e2-9437-14a7f161c7e8
# ╠═c37790b2-c7ac-41f1-8ee7-aaf3327af86a
# ╟─2b01d10f-ac30-41e8-a19b-76b7d9c3ec18
# ╟─9a13a391-441f-4015-a5d3-8125cb284da4
# ╠═c41ec10c-2063-4041-9be8-b15e0cfc21de
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
