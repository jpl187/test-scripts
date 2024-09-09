use clap::{crate_authors, crate_description, crate_name, crate_version, Arg, ArgAction, Command};
use reqwest::Url;
use std::{collections::HashMap, path::PathBuf, str::FromStr};
use vaas::{
    auth::authenticators::ClientCredentials, error::VResult, CancellationToken, Connection, Vaas,
    VaasVerdict,
};
use urlencoding::encode; // For URL encoding

#[tokio::main]
async fn main() -> VResult<()> {
    let matches = Command::new(crate_name!())
        .version(crate_version!())
        .author(crate_authors!())
        .about(crate_description!())
        .arg(
            Arg::new("files")
                .short('f')
                .long("files")
                .required_unless_present("urls")
                .action(ArgAction::Append)
                .help("List of files to scan separated by whitespace"),
        )
        .arg(
            Arg::new("urls")
                .short('u')
                .long("urls")
                .action(ArgAction::Append)
                .required_unless_present("files")
                .help("List of urls to scan separated by whitespace"),
        )
        .get_matches();

    let files = matches
        .get_many::<String>("files")
        .unwrap_or_default()
        .map(|f| PathBuf::from_str(f).unwrap_or_else(|_| panic!("Not a valid file path: {}", f)))
        .collect::<Vec<PathBuf>>();

    let urls = matches
        .get_many::<String>("urls")
        .unwrap_or_default()
        .map(|f| Url::parse(f).unwrap_or_else(|_| panic!("Not a valid url: {}", f)))
        .collect::<Vec<Url>>();

    // Hardcoded username and password
    let client_id = "your_vaas_username";
    let client_secret = "your_vaas_password_with_special_chars";

    // URL encode the client secret (password) to handle special characters
    let encoded_client_secret = encode(client_secret);

    let authenticator = ClientCredentials::new(client_id.to_owned(), encoded_client_secret.to_string());
    let vaas_connection = Vaas::builder(authenticator).build()?.connect().await?;

    let file_verdicts = scan_files(&files, &vaas_connection).await?;
    let url_verdicts = scan_urls(&urls, &vaas_connection).await?;

    file_verdicts
        .iter()
        .for_each(|(f, v)| print_verdicts(f.display().to_string(), v));

    url_verdicts.iter().for_each(|(u, v)| print_verdicts(u, v));

    Ok(())
}

fn print_verdicts<I: AsRef<str>>(i: I, v: &VResult<VaasVerdict>) {
    print!("{} -> ", i.as_ref());
    match v {
        Ok(v) => {
            println!("{}", v.verdict);
        }
        Err(e) => {
            println!("{}", e.to_string());
        }
    };
}

async fn scan_files<'a>(
    files: &'a [PathBuf],
    vaas_connection: &Connection,
) -> VResult<Vec<(&'a PathBuf, VResult<VaasVerdict>)>> {
    let ct = CancellationToken::from_minutes(1);
    let verdicts = vaas_connection.for_file_list(files, &ct).await;
    let results = files.iter().zip(verdicts).collect();

    Ok(results)
}

async fn scan_urls(
    urls: &[Url],
    vaas_connection: &Connection,
) -> VResult<HashMap<Url, Result<VaasVerdict, vaas::error::Error>>> {
    let ct = CancellationToken::from_minutes(1);
    let mut verdicts = HashMap::new();
    for url in urls {
        let verdict = vaas_connection.for_url(url, &ct).await;
        verdicts.insert(url.to_owned(), verdict);
    }

    Ok(verdicts)
}

