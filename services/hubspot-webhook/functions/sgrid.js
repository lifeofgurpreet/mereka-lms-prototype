import sgMail from '@sendgrid/mail';
class GridMail {
	static setApiKey(sendGridKey) {
		global.sendGridKey = sendGridKey;
		sgMail.setApiKey(sendGridKey);
	}
	constructor(sendGridKey) {
		if (!global.sendGridKey) {
			throw new Error('Please use GridMail.setApiKey(...) to set api key before use');
		}

		this.mailer = sgMail;
	}

	setTemplate(id) {
		this.templateId = id;
		return this;
	}

	setTemplateData(obj) {
		// Deep copy
		this.templateData = JSON.parse(JSON.stringify(obj));
		return this;
	}

	setTo(to) {
		this.to = to;
		return this;
	}

	setFrom(from) {
		this.from = from;
		return this;
	}

	async send() {
		await this.mailer.send({
			from: this.from,
			to: this.to,
			templateId: this.templateId,
			dynamic_template_data: this.templateData
		});

		return this;
	}
	async sendErrorEmail(error) {
		await this.mailer.sendMultiple({
			from: this.from,
			personalizations: ['0iamhira@gmail.com', 'gurpreet@biji-biji.com'].map((email) => {
				return {
					to: email,
					subject: "Error in MCT",
				};
			}),
			html: error,
		})
		return this;
	}
}

export default GridMail;