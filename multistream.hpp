#pragma once

#include "config-dialog.hpp"
#include "obs-websocket-api.h"
#include <obs.h>
#include <obs-frontend-api.h>
#include <QFrame>
#include <QPushButton>
#include <QString>
#include <QThreadPool>
#include <QTimer>
#include <QVBoxLayout>
#include <atomic>

class OBSBasicSettings;

class MultistreamDock : public QFrame {
	Q_OBJECT

private:
	OBSBasicSettings *configDialog = nullptr;

	obs_data_t *current_config = nullptr;

	QVBoxLayout *mainLayout = nullptr;
	QVBoxLayout *mainCanvasLayout = nullptr;
	QVBoxLayout *mainCanvasOutputLayout = nullptr;
	QVBoxLayout *verticalCanvasLayout = nullptr;
	QVBoxLayout *verticalCanvasOutputLayout = nullptr;
	QPushButton *mainStreamButton = nullptr;
	QPushButton *configButton = nullptr;
	QLabel *mainPlatformIconLabel = nullptr;
	QString mainPlatformUrl;

	QString newer_version_available;
	time_t partnerBlockTime = 0;

	QTimer videoCheckTimer;
	video_t *mainVideo = nullptr;
	std::vector<video_t *> oldVideo;

	std::vector<std::tuple<std::string, obs_output_t *, QPushButton *>> outputs;
	obs_data_array_t *vertical_outputs = nullptr;
	bool exiting = false;
	bool finished_loading = false;

	obs_websocket_vendor vendor = nullptr;

	void LoadSettingsFile();
	void LoadSettings();
	void LoadOutput(obs_data_t *data, bool vertical);
	void SaveSettings();

	bool StartOutput(obs_data_t *settings, QPushButton *streamButton);

	void startOutputAsync(obs_output_t *output, const std::string &name, bool remote);
	void outputStartFailed(obs_output_t *output, const std::string &name, const QString &reason, bool remote);

	// obs_output_start() runs on this pool instead of the UI thread. The
	// destructor waits for it before touching anything else, so a worker can
	// rely on the dock being alive for as long as it runs.
	QThreadPool startPool;
	// Read by the workers, so it cannot be the plain `exiting` flag.
	std::atomic<bool> startsCancelled{false};

	void outputButtonStyle(QPushButton *button);

	enum class OutputStatus { Normal, Warning, Error };

	void setOutputStatus(QPushButton *button, const QString &text, OutputStatus level);
	void postOutputStatus(obs_output_t *output, const QString &text, OutputStatus level);
	void reportStartFailure(QPushButton *streamButton, const QString &status, const QString &message, bool suppressDialog);

	// Set for the duration of a start or stop that came in over the
	// websocket, where there is nobody at the keyboard to dismiss a modal
	// dialog or answer a confirmation.
	bool remoteStart = false;
	bool remoteStop = false;

	void storeMainStreamEncoders();

	void AskUpdate();

	QIcon streamActiveIcon = QIcon(":/aitum/media/streaming.svg");
	QIcon streamInactiveIcon = QIcon(":/aitum/media/stream.svg");

	static void frontend_event(enum obs_frontend_event event, void *private_data);

	static void stream_output_stop(void *data, calldata_t *calldata);
	static void stream_output_start(void *data, calldata_t *calldata);
	static void stream_output_reconnect(void *data, calldata_t *calldata);
	static void stream_output_reconnect_success(void *data, calldata_t *calldata);

	static void vendor_request_version(obs_data_t *request_data, obs_data_t *response_data, void *self);
	static void vendor_request_get_outputs(obs_data_t *request_data, obs_data_t *response_data, void *self);
	static void vendor_request_start_output(obs_data_t *request_data, obs_data_t *response_data, void *self);
	static void vendor_request_stop_output(obs_data_t *request_data, obs_data_t *response_data, void *self);

private slots:
	void ApiInfo(QString info);

public:
	MultistreamDock(QWidget *parent = nullptr);
	~MultistreamDock();
	void LoadVerticalOutputs(bool firstLoad = true);
	void LoadWebsocket();
};

class AspectRatioPixmapLabel : public QLabel {
	Q_OBJECT
public:
	explicit AspectRatioPixmapLabel(QWidget *parent = 0);
	virtual int heightForWidth(int width) const;
	virtual QSize sizeHint() const;
	QPixmap scaledPixmap() const;
public slots:
	void setPixmap(const QPixmap &);
	void resizeEvent(QResizeEvent *);

private:
	QPixmap pix;
};
