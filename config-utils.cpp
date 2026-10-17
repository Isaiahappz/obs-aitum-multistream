#include "config-utils.hpp"

#include <QPushButton>
#include <QString>
#include <QFormLayout>
#include <QGroupBox>
#include <QComboBox>
#include <QAbstractButton>
#include <QWidget>
#include <QIcon>
#include <QToolButton>
#include <QPainter>
#include <QPixmap>
#include <QFont>

#include "obs.h"
#include "obs-module.h"
#include "obs-frontend-api.h"
#include <util/dstr.h>

bool ConfigUtils::isFacebookEndpoint(QString endpoint)
{
	return endpoint.contains(QStringLiteral("facebook.com"), Qt::CaseInsensitive);
}

int ConfigUtils::mainStreamKeyintSec()
{
	auto main_output = obs_frontend_get_streaming_output();
	if (!main_output) {
		return -1;
	}
	int keyint = -1;
	// The encoders only exist while the main stream is running, which is
	// also the only time an output can share them.
	auto venc = obs_output_get_video_encoder(main_output);
	if (venc) {
		auto settings = obs_encoder_get_settings(venc);
		if (settings) {
			keyint = (int)obs_data_get_int(settings, "keyint_sec");
			obs_data_release(settings);
		}
	}
	obs_output_release(main_output);
	return keyint;
}

// Generate buttons for default/custom stuff
QPushButton *ConfigUtils::generateButton(QString buttonText)
{
	auto styles = QString::fromUtf8("QPushButton[unselected=\"true\"] { background: pink; }");

	auto button = new QPushButton(buttonText);
	button->setStyleSheet(styles);

	return button;
}

// Generate settings groupbox
QGroupBox *ConfigUtils::generateSettingsGroupBox(QString headingText)
{
	auto group = headingText == nullptr ? new QGroupBox : new QGroupBox(headingText);
	//	group->setProperty("altColor", QVariant(true));

	return group;
}

// Generate menu button
QToolButton *ConfigUtils::generateMenuButton(QString title, QIcon icon)
{
	auto button = new QToolButton;

	button->setText(title);
	button->setIcon(icon);
	button->setIconSize(QSize(32, 32));
	button->setToolButtonStyle(Qt::ToolButtonTextUnderIcon);
	button->setStyleSheet(
		"min-width: 110px; max-width: 110px; min-height: 90px; max-height: 90px; padding-top: 16px; font-weight: bold;");

	return button;
}

// Generate QIcon from emoji
QIcon ConfigUtils::generateEmojiQIcon(QString emoji)
{
	QPixmap pixmap(32, 32);
	pixmap.fill(Qt::transparent);

	QPainter painter(&pixmap);
	QFont font = painter.font();
	font.setPixelSize(32);
	painter.setFont(font);
	painter.drawText(pixmap.rect(), Qt::AlignCenter, emoji);

	return QIcon(pixmap);
}

// For setting the active property stuff on buttons
void ConfigUtils::updateButtonStyles(QPushButton *defaultButton, QPushButton *customButton, int activeIndex)
{
	defaultButton->setProperty("unselected", activeIndex != 0 ? true : false);
	customButton->setProperty("unselected", activeIndex != 1 ? true : false);
}

// Platform identity deciphered from endpoints. The icon and the name come off
// the same table, so a row can never show one platform's logo beside another's
// name.
namespace {
struct Platform {
	const char *icon;
	const char *name; // nullptr when the endpoint belongs to nothing we know
};

static Platform platformFromEndpoint(const QString &endpoint)
{

	if (endpoint.contains(QString::fromUtf8("ingest.global-contribute.live-video.net")) ||
	    endpoint.contains(QString::fromUtf8(".contribute.live-video.net")) ||
	    endpoint.contains(QString::fromUtf8(".twitch.tv"))) { // twitch
		return {":/aitum/media/twitch.png", "Twitch"};
	} else if (endpoint.contains(QString::fromUtf8(".youtube.com"))) { // youtube
		return {":/aitum/media/youtube.png", "YouTube"};
	} else if (endpoint.contains(QString::fromUtf8("fa723fc1b171.global-contribute.live-video.net"))) { // kick
		return {":/aitum/media/kick.png", "Kick"};
	} else if (endpoint.contains(QString::fromUtf8(".tiktokcdn"))) { // tiktok
		return {":/aitum/media/tiktok.png", "TikTok"};
	} else if (endpoint.contains(QString::fromUtf8(".pscp.tv"))) { // twitter
		return {":/aitum/media/twitter.png", "X (Twitter)"};
	} else if (endpoint.contains(QString::fromUtf8("livepush.trovo.live"))) { // trovo
		return {":/aitum/media/trovo.png", "Trovo"};
	} else if (endpoint.contains(QString::fromUtf8(".facebook.com")) ||
		   endpoint.contains(QString::fromUtf8(".fbcdn.net"))) { // facebook
		return {":/aitum/media/facebook.png", "Facebook"};
	} else { // unknown
		return {":/aitum/media/unknown.png", nullptr};
	}
}
} // namespace

QIcon ConfigUtils::getPlatformIconFromEndpoint(QString endpoint)
{
	return QIcon(QString::fromUtf8(platformFromEndpoint(endpoint).icon));
}

QString ConfigUtils::getPlatformNameFromEndpoint(QString endpoint)
{
	auto name = platformFromEndpoint(endpoint).name;
	return name ? QString::fromUtf8(name) : QString();
}
