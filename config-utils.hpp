#pragma once

#include <QPushButton>
#include <QComboBox>
#include <QFormLayout>
#include <QVBoxLayout>
#include <QWidget>
#include <QGroupBox>
#include <QIcon>
#include <QString>
#include <QToolButton>
#include "obs.h"

class ConfigUtils {
public:
	// UI generation
	static QPushButton *generateButton(QString buttonText);
	static QGroupBox *generateSettingsGroupBox(QString headingText);
	static QToolButton *generateMenuButton(QString title, QIcon icon);

	static QIcon generateEmojiQIcon(QString emoji);

	static void updateButtonStyles(QPushButton *defaultButton, QPushButton *customButton, int activeIndex);

	static QIcon getPlatformIconFromEndpoint(QString endpoint);

	// Facebook wants a keyframe at least every 2 seconds.
	static bool isFacebookEndpoint(QString endpoint);
	// The main stream's keyframe interval in seconds, 0 for automatic, or -1
	// when it cannot be read because the main stream has no encoder yet.
	static int mainStreamKeyintSec();
};
