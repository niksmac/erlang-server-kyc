-module(swagger_router).

-export([get_paths/1]).

-type operations() :: #{
    Method :: binary() => swagger_api:operation_id()
}.

-type init_opts()  :: {
    Operations :: operations(),
    LogicHandler :: atom(),
    ValidatorState :: jesse_state:state()
}.

-export_type([init_opts/0]).

-spec get_paths(LogicHandler :: atom()) ->  [{'_',[{
    Path :: string(),
    Handler :: atom(),
    InitOpts :: init_opts()
}]}].

get_paths(LogicHandler) ->
    ValidatorState = prepare_validator(),
    PreparedPaths = maps:fold(
        fun(Path, #{operations := Operations, handler := Handler}, Acc) ->
            [{Path, Handler, Operations} | Acc]
        end,
        [],
        group_paths()
    ),
    [
        {'_',
            [{P, H, {O, LogicHandler, ValidatorState}} || {P, H, O} <- PreparedPaths]
        }
    ].

group_paths() ->
    maps:fold(
        fun(OperationID, #{path := Path, method := Method, handler := Handler}, Acc) ->
            case maps:find(Path, Acc) of
                {ok, PathInfo0 = #{operations := Operations0}} ->
                    Operations = Operations0#{Method => OperationID},
                    PathInfo = PathInfo0#{operations => Operations},
                    Acc#{Path => PathInfo};
                error ->
                    Operations = #{Method => OperationID},
                    PathInfo = #{handler => Handler, operations => Operations},
                    Acc#{Path => PathInfo}
            end
        end,
        #{},
        get_operations()
    ).

get_operations() ->
    #{ 
        'ApiKycsCallbackProviderPost' => #{
            path => "/api/kycs/callback/:provider",
            method => <<"POST">>,
            handler => 'swagger_default_handler'
        },
        'ApiKycsCodePost' => #{
            path => "/api/kycs/code",
            method => <<"POST">>,
            handler => 'swagger_default_handler'
        },
        'ApiKycsInitPost' => #{
            path => "/api/kycs/init",
            method => <<"POST">>,
            handler => 'swagger_default_handler'
        },
        'ApiKycsIdPut' => #{
            path => "/api/kycs/:id",
            method => <<"PUT">>,
            handler => 'swagger_kyc_handler'
        },
        'ApiKycsIsvalidUserIdGet' => #{
            path => "/api/kycs/isvalid/:userId",
            method => <<"GET">>,
            handler => 'swagger_kyc_handler'
        },
        'ApiKycsPost' => #{
            path => "/api/kycs",
            method => <<"POST">>,
            handler => 'swagger_kyc_handler'
        },
        'ApiKycsSignatureUserIdGet' => #{
            path => "/api/kycs/signature/:userId",
            method => <<"GET">>,
            handler => 'swagger_kyc_handler'
        }
    }.

prepare_validator() ->
    R = jsx:decode(element(2, file:read_file(get_swagger_path()))),
    jesse_state:new(R, [{default_schema_ver, <<"http://json-schema.org/draft-04/schema#">>}]).


get_swagger_path() ->
    {ok, AppName} = application:get_application(?MODULE),
    filename:join(swagger_utils:priv_dir(AppName), "swagger.json").


