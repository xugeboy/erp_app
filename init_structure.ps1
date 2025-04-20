
$basePath = "D:\workspace\erp_app\lib"

$structure = @{
    "app" = @{
        "routes" = @(
            "app_router.dart",
            "app_routes.dart"
        )
        "providers" = @(
            "app_providers.dart"
        )
        "" = @("app_widget.dart")
    }
    "core" = @{
        "api" = @("api_client.dart")
        "constants" = @("api_constants.dart", "app_constants.dart")
        "error" = @("exceptions.dart", "failure.dart")
        "navigation" = @()
        "storage" = @("local_storage_service.dart")
        "theme" = @("app_colors.dart", "app_text_styles.dart", "app_theme.dart")
        "usecases" = @("usecase.dart")
        "utils" = @("validators.dart")
    }
    "features" = @{
        "auth" = @{
            "data" = @{
                "datasources" = @("auth_remote_datasource.dart")
                "models" = @("user_model.dart")
                "repositories" = @("auth_repository_impl.dart")
            }
            "domain" = @{
                "entities" = @("user.dart")
                "repositories" = @("auth_repository.dart")
                "usecases" = @("login_usecase.dart")
            }
            "presentation" = @{
                "pages" = @("login_page.dart")
                "state" = @{
                    "login_bloc" = @("login_bloc.dart", "login_event.dart", "login_state.dart")
                }
                "widgets" = @("login_form.dart")
            }
        }
        "orders" = @{
            "data" = @()
            "domain" = @()
            "presentation" = @()
        }
        "inventory" = @{}
    }
    "shared" = @{
        "widgets" = @("loading_indicator.dart", "error_message.dart")
    }
    "" = @("main.dart")
}

function Create-Structure($path, $structure) {
    foreach ($key in $structure.Keys) {
        $currentPath = Join-Path $path $key
        if ($key -ne "") {
            New-Item -Path $currentPath -ItemType Directory -Force | Out-Null
        } else {
            $currentPath = $path
        }

        foreach ($item in $structure[$key]) {
            if ($item -is [string]) {
                New-Item -Path (Join-Path $currentPath $item) -ItemType File -Force | Out-Null
            } elseif ($item -is [hashtable]) {
                Create-Structure -path $currentPath -structure $item
            }
        }
    }
}

Create-Structure -path $basePath -structure $structure