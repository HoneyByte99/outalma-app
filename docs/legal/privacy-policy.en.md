# Privacy Policy of Outalma Service

Last updated: 6 September 2026

This policy describes how **KAYZEN TECHNOLOGY** ("we", "us", "our"), publisher of the Outalma Service application, collects, uses and protects your personal data when you use our mobile application and our website (together, the "Application"). Outalma Service is a services marketplace for users based in France and Senegal. A single account may act as a **customer** (booking services) and as a **provider** (offering services).

We are committed to complying with the General Data Protection Regulation (EU 2016/679, "GDPR"), the French Data Protection Act ("Loi Informatique et Libertés"), as well as **Senegalese Law No. 2008-12 of 25 January 2008** on the protection of personal data.


## 1. Identity of the data controller

The data controller is:

- **Company name**: KAYZEN TECHNOLOGY
- **Legal form / registration number**: [to be completed before publication]
- **Registered office address**: [to be completed before publication]
- **Contact email**: contact@outalma.com
- **Data Protection Officer (DPO)**: not designated to date


## 2. Data we collect

We limit collection to the data necessary for the operation of the service.

### 2.1 Identity data
- First name, last name, displayed username
- Profile photo (optional)
- Date of birth (minimum age verification)

### 2.2 Contact data
- Email address
- Phone number (international E.164 format)

Your phone number is **never displayed publicly**. It is made visible only between a customer and a provider **after acceptance of a booking**, in order to facilitate coordination of the service (a model inspired by BlaBlaCar).

### 2.3 User content
- Published service listings (title, description, prices, photos)
- Messages exchanged in chat (text, images, voice messages) between participants of a booking
- Reviews and ratings left after a service

### 2.4 Location data
- Declared address or service area
- Approximate position for searching nearby providers (via Google Maps / Places). Precise geolocation is only used with your explicit consent via the operating system's permissions.

### 2.5 Technical data
- Firebase user identifier
- Device model, operating system version, Application version
- Push notification tokens (Firebase Cloud Messaging)
- Anonymised crash logs (Firebase Crashlytics)
- IP address (transiently, during calls to backend services)


## 3. Purposes of processing

Your data is used to:

1. **Authentication**: create and secure your account via email (magic link) or phone (OTP code).
2. **Provision of the service**: publish listings, search, book, exchange via chat, manage reviews.
3. **Communication**: send you notifications relating to your bookings, messages, or changes to your account.
4. **Security**: detect fraud, abuse, multiple accounts or behaviour prohibited by our Terms of Use.
5. **Service improvement**: fix bugs (via Crashlytics) and improve usability. We use **no third-party behavioural analytics tool**.
6. **Legal compliance**: respond to a legal or regulatory obligation, or to a judicial request.


## 4. Legal bases (GDPR Article 6)

| Purpose | Legal basis |
|---|---|
| Account creation and performance of bookings | Performance of a contract (Art. 6.1.b) |
| Security, fraud prevention | Legitimate interest (Art. 6.1.f) |
| Push notifications | Consent (Art. 6.1.a), revocable from settings |
| Precise geolocation | Consent (Art. 6.1.a) |
| Crashlytics (technical diagnostics) | Legitimate interest (Art. 6.1.f) |
| Possible accounting and tax retention | Legal obligation (Art. 6.1.c) |

In Senegal, this processing relies on the bases set out in articles 33 et seq. of Law No. 2008-12 (consent, contractual performance, legitimate interest, legal obligation).


## 5. Processors and recipients

We **never sell** your data. We display **no advertising** within the Application. Your data is only shared with the technical processors strictly necessary:

| Processor | Role | Server location |
|---|---|---|
| **Google / Firebase** (Auth, Firestore, Cloud Functions, Storage, Cloud Messaging, Crashlytics) | Hosting, authentication, database, file storage, notifications, crash reports | European Union (`europe-west` region) with global Google operations |
| **Twilio Verify** | Sending OTP codes by SMS | United States, Ireland |
| **Google Maps Platform / Places API** | Mapping, address search, distance calculation | Global Google operations |

The other recipients are **the users themselves**: a profile's public information (first name, photo, services offered, reviews) is visible to other users. The phone number is only shared between the two participants of an accepted booking.


## 6. Retention period

| Data | Period |
|---|---|
| Active account | For as long as the account exists |
| Inactive account (no login) | 3 years after last activity, then deletion or anonymisation |
| Chat messages | 2 years after the end of the associated booking |
| Booking history | 5 years (evidence in the event of a dispute) |
| Crash reports (Crashlytics) | 90 days |
| Billing data (where applicable) | 10 years (accounting obligation) |

You may at any time request the deletion of your account from within the Application. Data will be erased unless subject to a legal retention obligation.


## 7. Your rights

In accordance with the GDPR and Senegalese Law No. 2008-12, you have the following rights:

- **Access**: obtain a copy of your data
- **Rectification**: correct inaccurate data
- **Erasure** ("right to be forgotten")
- **Portability**: receive your data in a structured format
- **Objection** to processing based on legitimate interest
- **Restriction** of processing
- **Withdrawal of consent** at any time (without retroactive effect)
- **Setting directives** on the fate of your data after your death

To exercise these rights, write to us at: **contact@outalma.com**. A response will be provided within **one month**. Proof of identity may be requested in case of reasonable doubt.


## 8. Transfers outside the European Union

Certain processors (Google, Twilio) may process your data outside the European Union, in particular in the United States. These transfers are governed by:

- adherence to the **EU-US Data Privacy Framework (DPF)** where the company is certified under it,
- the **Standard Contractual Clauses** adopted by the European Commission (Decision 2021/914),
- additional technical security measures (encryption in transit and at rest).

For Senegalese users, international transfers comply with articles 49 et seq. of Law No. 2008-12 and require an adequate level of protection.


## 9. Data security

We implement reasonable technical and organisational measures:

- TLS encryption for all client / server communications
- Encryption at rest of data stored with Firebase
- Strong authentication (magic link or OTP code, with no password to remember)
- Firestore and Storage security rules restricting access to authorised persons only
- Access logs and alerts in the event of suspicious activity
- Access to data restricted to the only team members who need it

As no system is infallible, we undertake to notify you of any data breach likely to result in a high risk to your rights, within **72 hours** of becoming aware of it, in accordance with Article 33 of the GDPR.


## 10. Cookies and trackers (website)

The web version of Outalma uses only:

- **strictly necessary cookies** for operation (session, authentication, language preferences),
- technical cookies set by Firebase Hosting and Firebase Auth.

We use **no advertising cookie, no tracking pixel, no third-party analytics tracker** beyond Firebase Crashlytics (which does not set a browser-side cookie).

No consent banner is therefore required for non-essential cookies, since we do not set any. You may delete cookies at any time from your browser's settings.


## 11. Minors' data

The Application is reserved for persons aged at least **16 years**. We do not knowingly collect data concerning minors under 16. If you believe that a minor under 16 has provided us with data, contact us: we will delete the account concerned.


## 12. Amendment of the policy

This policy may evolve over time (new features, change of processor, legal developments). Any substantial amendment will be notified to you within the Application and/or by email, at least **15 days before** it takes effect, so as to allow you to exercise your rights.

The date at the top of this document always indicates the version in force.


## 13. Contact and complaints

For any question relating to your personal data:

- **Email**: contact@outalma.com
- **Postal address**: KAYZEN TECHNOLOGY [address to be completed before publication]

If you believe that your rights are not being respected, you may lodge a complaint with:

- **France**: Commission Nationale de l'Informatique et des Libertés (CNIL), 3 place de Fontenoy, TSA 80715, 75334 Paris Cedex 07. Website: [www.cnil.fr](https://www.cnil.fr)
- **Senegal**: Commission des Données Personnelles (CDP), Immeuble Y2K, 1er étage, Rond-Point OMVS, Dakar. Website: [www.cdp.sn](https://www.cdp.sn)


## 14. Effective date

This policy has been in force since **6 September 2026**.


## 15. Governing language

This policy is drawn up in French and in English. In the event of any discrepancy or inconsistency between the two versions, the **French version shall prevail**; the English version is provided for information purposes only.
