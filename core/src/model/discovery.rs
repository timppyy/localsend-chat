use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Eq, Serialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DeviceType {
    #[serde(alias = "mobile")]
    Mobile,
    #[serde(alias = "desktop")]
    Desktop,
    #[serde(alias = "web")]
    Web,
    #[serde(alias = "headless")]
    Headless,
    #[serde(alias = "server")]
    Server,
}
